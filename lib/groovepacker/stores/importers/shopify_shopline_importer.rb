# frozen_string_literal: true

module Groovepacker
  module Stores
    module Importers
      class ShopifyShoplineImporter < Importer
        include ProductsHelper

        def import
          @import_webhook_order = $redis.get("webhook_import_started_#{Apartment::Tenant.current}").to_b
          initialize_import_objects
          begin
            OrderImportSummary.top_summary.emit_data_to_user(true)
          rescue StandardError
            nil
          end
          return @result unless @import_item.present?

          @import_item.update_column(:importer_id, @worker_id)
          response = @client.orders(@import_item)
          @result[:total_imported] = response['orders'].nil? ? 0 : response['orders'].length
          initialize_import_item
          return @result if response['orders'].nil? || response['orders'].blank? || response['orders'].first.nil?

          response['orders'] = begin
                                  response['orders'].sort_by { |h| Time.zone.parse(h['updated_at']) }
                                rescue StandardError
                                  response['orders']
                                end

          ImportItem.where(store_id: @store.id).where.not(id: @import_item).update_all(status: 'cancelled')
          Groovepacker::Stores::Importers::LogglyLog.log_orders_response(response['orders'], @store, @import_item) if current_tenant_object&.loggly_shopify_imports

          response['orders'].each do |order|
            break if import_should_be_cancelled

            import_single_order(order) if order.present?
            @credential.update_attributes(last_imported_at: Time.zone.parse(order['updated_at']))
          end
          Tenant.save_se_import_data('==ImportItem', @import_item.as_json, '==OrderImportSumary', @import_item.try(:order_import_summary).try(:as_json))
          if @import_item.status != 'cancelled'
            begin
              @credential.update_attributes(last_imported_at: Time.zone.parse(response['orders'].last['updated_at']))
            rescue StandardError
              nil
            end
          end
          $redis.del("webhook_import_started_#{Apartment::Tenant.current}")
          update_orders_status
          @result
        end

        def ondemand_import_single_order(order_number, user_id)
          @on_demand_import = true
          @ondemand_user_name = ondemand_user(user_id)
          init_common_objects
          response = @client.get_single_order(order_number)
          order_response = response['orders']&.any? ? response['orders'].first : nil
          import_single_order(order_response) if order_response
          begin
            @import_item.destroy
          rescue StandardError
            nil
          end
        end

        private

        def initialize_import_objects
          handler = get_handler
          @credential = handler[:credential]
          @store = @credential.store
          @client = handler[:store_handle]
          @import_item = handler[:import_item]
          @result = build_result
          @worker_id = 'worker_' + SecureRandom.hex
        end

        def import_single_order(order)
          @import_item.update_attributes(current_increment_id: order['id'], current_order_items: -1, current_order_imported_item: -1)

          update_import_count('success_updated') && return if skip_the_order?(order)

          order_in_gp_present = false
          order_in_gp = Order.find_by_store_order_id(order['id'].to_s)

          veeqo_shopify_order_import(order_in_gp_present, order_in_gp, order)
        end

        def import_order(shop_order, order)
          shop_order.tags = order['tags']
          shop_order.customer_comments = order['note']
          shop_order.increment_id = order['name']
          shop_order.store_order_id = order['id'].to_s
          shop_order.order_placed_time = Time.zone.parse(order['created_at'])
          # add order shipping address using separate method
          shop_order = add_customer_info(shop_order, order)
          # add order shipping address using separate method
          shop_order = add_order_shipping_address(shop_order, order)
          # update shipping_amount and order weight
          shop_order = update_shipping_amount_and_weight(shop_order, order)
          shop_order.order_total = order['total_price']&.to_f || order['current_total_price'].to_f
          shop_order.last_modified = Time.zone.parse(order['updated_at'])
          shop_order.tracking_num = get_tracking_number(order)
          shop_order.job_timestamp = Time.current.strftime('%Y-%m-%d %H:%M:%S.%L')
          shop_order
        end

        def get_tracking_number(order)
          (order['fulfillments'] || []).map { |f| f['tracking_number'] }.reject(&:blank?).first
        rescue StandardError => e
          nil
        end

        def import_fulfilled_having_tracking
          @import_fulfilled_having_tracking ||= @credential.import_fulfilled_having_tracking
        end

        def import_order_items(shop_order, order)
          return if order['line_items'].nil?

          @import_item.current_order_items = order['line_items'].length
          @import_item.current_order_imported_item = 0
          @import_item.save!
          # order['line_items'] = order['line_items'].reject { |h| h['fulfillment_status'].nil? && h['fulfillable_quantity'] == 0 }
          order['line_items'] = check_removed_items_quantity(order)
          order['line_items']&.each do |item|
            order_item = import_order_item(item)
            @import_item.update!(current_order_imported_item: @import_item.current_order_imported_item + 1)
            product = Product.joins(:product_skus).find_by(product_skus: { sku:item['sku'] }) || shop_context.import_shop_single_product(item)
            if product.present?
              order_item.product = product
              shop_order.order_items << order_item
            else
              on_demand_logger = Logger.new("#{Rails.root}/log/#{@store.store_type.downcase}_missing_product_import_order_item_#{Apartment::Tenant.current}.log")
              log = { order_number: shop_order.increment_id, Time: Time.zone.now, shop_order_item: item, product: product }
              on_demand_logger.info(log)
            end
          end
          shop_order.save!
          shop_order
        end

        def import_order_item(line_item)
          row_total = line_item['price'].to_f * line_item['quantity'].to_f
          order_item = OrderItem.new(qty: line_item['quantity'],
                                      price: line_item['price'],
                                      row_total: row_total)
        end

        def add_customer_info(shop_order, order)
          return shop_order if order['customer'].nil?

          shop_order.email = order['customer']['email']
          shop_order.firstname = order['shipping_address'].try(:[], 'first_name')
          shop_order.lastname = order['shipping_address'].try(:[], 'last_name')
          shop_order
        end

        def add_order_shipping_address(shop_order, order)
          shipping_address = order['shipping_address']
          return shop_order if shipping_address.blank?

          shop_order.address_1 = shipping_address['address1']
          shop_order.address_2 = shipping_address['address2']
          shop_order.city = shipping_address['city']
          shop_order.state = shipping_address['province']
          shop_order.postcode = shipping_address['zip']
          shop_order.country = shipping_address['country']
          shop_order
        end

        def update_shipping_amount_and_weight(shop_order, order)
          unless order['shipping_lines'].empty?
            shipping = order['shipping_lines'].first
            shop_order.shipping_amount = shipping['price'].to_f unless shipping.nil?
          end

          shop_order.weight_oz = (order['total_weight'].to_i * 0.035274) unless order['total_weight'].nil?
          shop_order
        end

        def shop_context
          if @store.store_type == 'Shopline'
            handler = Groovepacker::Stores::Handlers::ShoplineHandler.new(@store)
          elsif @store.store_type == 'Shopify'
            handler = Groovepacker::Stores::Handlers::ShopifyHandler.new(@store)
          end

          Groovepacker::Stores::Context.new(handler)
        end

        def add_order_activities(shop_order)
          order_import_type = @on_demand_import ? 'On Demand Order Import' : (@import_webhook_order ? 'Webhook Order Import' : 'Order Import')
          shop_order.addactivity(order_import_type, @store.name + " Import #{@ondemand_user_name}")
          shop_order.order_items.each do |item|
            next if item.product.nil? || item.product.primary_sku.nil?

            shop_order.addactivity('Item with SKU: ' + item.product.primary_sku + ' Added', @store.name + ' Import')
          end
        end

        def add_order_activities_for_gp_coupon(shop_order, order)
          order_import_type = @on_demand_import ? 'On Demand Order Import' : (@import_webhook_order ? 'Webhook Order Import' : 'Order Import')
          shop_order.addactivity(order_import_type, @store.name + " Import #{@ondemand_user_name}")
          shop_order.order_items.each_with_index do |item, index|
            if order['line_items'][index]['name'] == item.product.name && order['line_items'][index]['sku'] == item.product.primary_sku
              next if item.product.nil? || item.product.primary_sku.nil?

              shop_order.addactivity("QTY #{item.qty} of item with SKU: #{item.product.primary_sku} Added", "#{@store.name} Import")
            else
              intangible_strings = ScanPackSetting.all.first.intangible_string.downcase.strip.split(',')
              activity_added = false
              intangible_strings.each do |string|
                is_intangible = begin
                                    (order['line_items'][index]['name'].downcase.include?(string) || order['line_items'][index]['sku'].downcase.include?(string))
                                rescue StandardError
                                  nil
                                  end
                next unless is_intangible

                shop_order.addactivity("Intangible item with SKU #{order['line_items'][index]['sku']}  and Name #{order['line_items'][index]['name']} was replaced with GP Coupon.", "#{@store.name} Import")
                activity_added = true
                break
              end
              shop_order.addactivity("QTY #{item.qty} of item with SKU: #{item.product.primary_sku} Added", "#{@store.name} Import") if !activity_added && item.product.try(:primary_sku)
            end
          end
        end

        def import_order_and_items(order, order_in_gp)
          # create order
          shop_order = order_in_gp
          Order.transaction do
            shop_order = import_order(shop_order, order)
            # import items in an order
            shop_order = import_order_items(shop_order, order)
            # update store
            shop_order.set_order_status
            # add order activities
            if check_for_replace_product
              add_order_activities_for_gp_coupon(shop_order, order)
            else
              add_order_activities(shop_order)
            end
          end
        end

        def check_removed_items_quantity(order)
          order['refunds'] = order['refunds'] || []

          order_refunds = order['refunds'].map { |h| h['refund_line_items'] }
          order['line_items'].each do |line_item|
            order_refunds.each do |refund|
              line_item['quantity'] -= begin
                                          refund.select { |ref| ref['line_item_id'] == line_item['id'] && (ref['restock_type'] == 'cancel' || ref['restock_type'] == 'no_restock') }.map { |h| h['quantity'] }.sum
                                        rescue StandardError
                                          nil
                                        end
            end
          end
          order['line_items'].reject { |item| item['quantity'] <= 0 }
        rescue StandardError
          order['line_items']
        end

        def skip_the_order?(order)
          return false if @on_demand_import

          import_fulfilled_having_tracking && order['fulfillment_status'] == 'fulfilled' && !get_tracking_number(order).present?
        end
      end
    end
  end
end
