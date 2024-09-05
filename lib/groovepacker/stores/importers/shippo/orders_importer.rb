module Groovepacker
  module Stores
    module Importers
      module Shippo
        class OrdersImporter < Groovepacker::Stores::Importers::Importer
          include ProductsHelper

          def import
            initialize_import_objects
            OrderImportSummary.top_summary.emit_data_to_user(true) rescue nil
            return @result unless @import_item.present?

            @import_item.update_column(:importer_id, @worker_id)
            response = @client.orders(@import_item)
            @result[:total_imported] = response['orders']&.length || 0
            initialize_import_item
            return @result if response['orders'].nil? || response['orders'].blank? || response['orders'].first.nil?
            response['orders'] = response['orders'].sort_by { |h| Time.zone.parse(h['placed_at']) } rescue response['orders']
            response['orders'].each do |order|
              import_item_fix
              ImportItem.where(store_id: @store.id).where.not(status: %w[failed completed]).order(:created_at).drop(1).each { |item| item.update_column(:status, 'cancelled') }

              break if import_should_be_cancelled
              import_single_order(order) if order.present? && active_statuses.include?(order['order_status'])
              @credential.update(last_imported_at: Time.zone.parse(order['placed_at']))
            end
            Tenant.save_se_import_data('==ImportItem', @import_item.as_json, '==OrderImportSumary', @import_item.try(:order_import_summary).try(:as_json))
            @credential.update(last_imported_at: Time.zone.now) rescue nil if @import_item.status != 'cancelled'
            update_orders_status
            @result
          end

          def range_import(start_date, end_date, type, user_id)
            init_common_objects
            initialize_import_item
            start_date = Time.zone.parse(start_date).strftime("%Y-%m-%d %H:%M:%S")
            end_date = Time.zone.parse(end_date).strftime("%Y-%m-%d %H:%M:%S")
            init_order_import_summary(user_id)
            response = @client.get_ranged_orders(start_date, end_date)
            @import_item.update(to_import: response['orders'].count)
            response["orders"].each do |order|
              import_single_order(order) if order.present? && active_statuses.include?(order['order_status'])
            end
            update_order_import_summary
          end

          def ondemand_import_single_order(order_number, user_id)
            @on_demand_import = true
            @ondemand_user_name = ondemand_user(user_id)
            init_common_objects
            response = @client.get_single_order(order_number)
            order_response = response&.any? ? response : nil
            import_single_order(order_response) if order_response
            @import_item.destroy rescue nil
          end

          private

          def active_statuses
            status = @credential.get_active_statuses
          end

          def shippo_context
            handler = Groovepacker::Stores::Handlers::ShippoHandler.new(@store)
            context = Groovepacker::Stores::Context.new(handler)
            context
          end

          def initialize_import_objects
            handler = self.get_handler
            @credential = handler[:credential]
            @store = @credential.store
            @client = handler[:store_handle]
            @import_item = handler[:import_item]
            @result = self.build_result
            @worker_id = 'worker_' + SecureRandom.hex
          end

          def init_order_import_summary(user_id)
            OrderImportSummary.where("status != 'in_progress' OR status = 'completed'").destroy_all
            ImportItem.where(store_id: @store.id).where("status = 'cancelled' OR status = 'completed'").destroy_all
            @import_summary = OrderImportSummary.top_summary
            @import_summary = OrderImportSummary.create(user_id: user_id, status: 'not_started', display_summary: false) unless @import_summary
            @import_item.update(order_import_summary_id: @import_summary.id, status: 'not_started')
            @range_or_quickfix_started = true
            @import_summary.emit_data_to_user(true)
          end

          def update_order_import_summary
            @import_item.update(status: 'completed') if @import_item.reload.status != 'cancelled'
            destroy_nil_import_items
            @import_summary.update(status: 'completed') if OrderImportSummary.joins(:import_items).where("import_items.status = 'in_progress' OR import_items.status = 'not_started'").blank?
            @import_summary.emit_data_to_user(true)
          end

          def import_single_order(order)
            @import_item.update(:current_increment_id => order["id"], :current_order_items => -1, :current_order_imported_item => -1)

            update_import_count('success_updated') && return if skip_the_order?(order)

            order_in_gp_present = false
            order_in_gp = Order.find_by_store_order_id(order["object_id"].to_s)
            if order_in_gp
              order_in_gp_present = true
              is_scanned = order_in_gp && (order_in_gp.status=="scanned" || order_in_gp.status=="cancelled" || order_in_gp.order_items.map(&:scanned_status).include?("partially_scanned") || order_in_gp.order_items.map(&:scanned_status).include?("scanned"))
              #mark previously imported
              update_import_count('success_updated') && return if is_scanned || (order_in_gp.last_modified == Time.zone.parse(order['placed_at']))
              order_in_gp.order_items.destroy_all
            else
              order_in_gp = Order.new(increment_id: order['name'], store: @store)
            end

            Order.transaction do
              import_order_and_items(order, order_in_gp)
            end

            update_import_count(order_in_gp_present ? 'success_updated' : 'success_imported')
          end

          def import_order(shippo_order, order)
            shippo_order.increment_id = order['order_number']
            shippo_order.store_order_id = order["object_id"].to_s
            shippo_order.order_placed_time = Time.zone.parse(order["placed_at"])
            #add order shipping address using separate method
            shippo_order = add_customer_info(shippo_order, order)
            #add order shipping address using separate method
            shippo_order = add_order_shipping_address(shippo_order, order)
            #update shipping_amount and order weight
            shippo_order = update_shipping_amount_and_weight(shippo_order, order)
            shippo_order.order_total = order["total_price"].to_f unless order["total_price"].nil?
            shippo_order.last_modified = Time.zone.parse(order['placed_at']) unless order['placed_at'].nil?
            shippo_order.tracking_num = order_tracking_number(order)
            shippo_order.importer_id = @worker_id rescue nil
            shippo_order.import_item_id = @import_item.id rescue nil
            shippo_order.job_timestamp = Time.current.strftime("%Y-%m-%d %H:%M:%S.%L")
            return shippo_order
          end

          def order_tracking_number(order)
            order['transactions'].select { |transaction| transaction['tracking_number'] != nil }.first.try(:[], 'tracking_number')
          end

          def import_order_items(shippo_order, order)
            return if order['line_items'].nil?
            @import_item.current_order_items = order['line_items'].length
            @import_item.current_order_imported_item = 0
            @import_item.save
            order['line_items'].each do |item|
              order_item = import_order_item(order_item, item)
              @import_item.update(current_order_imported_item: @import_item.current_order_imported_item + 1)
              product = Product.joins(:product_skus).find_by(product_skus: { sku: item['sku'] }) || shippo_context.import_shippo_single_product(item)
              insert_order_item(order_item, shippo_order, product)

              product.add_product_activity('Product Import',"#{product.store.try(:name)}") if product.product_activities.blank?
            end
            shippo_order.save
            shippo_order
          end

          def import_order_item(order_item, line_item)
            row_total = line_item["total_price"].to_f * line_item["quantity"]
            order_item = OrderItem.new(
                    qty: line_item["quantity"],
                    price: line_item["total_price"],
                    row_total: row_total
                    )
          end

          def insert_order_item(order_item, shippo_order, product)
            order_item.product = product
            shippo_order.order_items << order_item
            shippo_order
          end

          def add_customer_info(shippo_order, order)
            return shippo_order if order["to_address"].nil?
            shippo_order.email = order["to_address"]["email"]
            shippo_order.lastname = order["to_address"]["name"].split(' ').last
            shippo_order.firstname = order["to_address"]["name"].split(' ').first
            return shippo_order
          end

          def add_order_shipping_address(shippo_order, order)
            shipping_address = order["to_address"]
            return shippo_order if shipping_address.blank?
            shippo_order.address_1 = shipping_address["street1"]
            shippo_order.address_2 = shipping_address["street2"]
            shippo_order.city = shipping_address["city"]
            shippo_order.state = shipping_address["state"]
            shippo_order.postcode = shipping_address["zip"]
            shippo_order.country = shipping_address["country"]
            return shippo_order
          end

          def update_shipping_amount_and_weight(shippo_order, order)
            unless order["to_address"].nil?
              shippo_order.shipping_amount = order["shipping_cost"].to_f unless order["to_address"].nil?
            end

            shippo_order.weight_oz = (order["weight"].to_i * 0.035274) unless order["weight"].nil?
            return shippo_order
          end

          def update_import_count(import_type = 'success_imported')
            if import_type == 'success_imported'
              @import_item.update(:success_imported => @import_item.success_imported+1)
              @result[:success_imported] += 1
            else
              @result[:previous_imported] += 1
              @import_item.update(:updated_orders_import => @import_item.updated_orders_import + 1)
            end
          end

          def add_order_activities(shippo_order)
            activity_name = @on_demand_import ? 'On Demand Order Import' : 'Order Import'
            shippo_order.addactivity(activity_name, @store.name + " Import #{@ondemand_user_name}")
            shippo_order.order_items.each do |item|
              next if item.product.nil? || item.product.primary_sku.nil?
              shippo_order.addactivity("Item with SKU: "+item.product.primary_sku+" Added", @store.name+" Import")
            end
          end

          def add_order_activities_for_gp_coupon(shippo_order, order)
            activity_name = @on_demand_import ? 'On Demand Order Import' : 'Order Import'
            shippo_order.addactivity(activity_name, @store.name + " Import #{@ondemand_user_name}")
            shippo_order.order_items.each_with_index do |item, index|
              if order["line_items"][index]["title"] == item.product.name &&  order["line_items"][index]["sku"] == item.product.primary_sku
                next if item.product.nil? || item.product.primary_sku.nil?
                shippo_order.addactivity("QTY #{item.qty} of item with SKU: #{item.product.primary_sku} Added", "#{@store.name} Import")
              else
                intangible_strings = ScanPackSetting.all.first.intangible_string.downcase.strip.split(',')
                activity_added = false
                intangible_strings.each do |string|
                  if is_intangible(order, string, index)
                    shippo_order.addactivity("Intangible item with SKU #{order["line_items"][index]["sku"]}  and Name #{order["line_items"][index]["title"]} was replaced with GP Coupon.","#{@store.name} Import")
                    activity_added = true
                    break
                  end
                end
                shippo_order.addactivity("QTY #{item.qty} of item with SKU: #{item.product.primary_sku} Added", "#{@store.name} Import") if !activity_added && item.product.try(:primary_sku)
              end
            end
          end

          def is_intangible(order, string, index)
            order["line_items"][index]["title"].downcase.include?(string) || order["line_items"][index]["sku"].downcase.include?(string)
          end

          def import_order_and_items(order, order_in_gp)
            #create order
            shippo_order = order_in_gp
            shippo_order.transaction do
              shippo_order = import_order(shippo_order, order)
              #import items in an order
              shippo_order = import_order_items(shippo_order, order)
              #update store
              shippo_order.set_order_status
              #add order activities
              if check_for_replace_product
                add_order_activities_for_gp_coupon(shippo_order, order)
              else
                add_order_activities(shippo_order)
              end
            end
          end

          def skip_the_order?(order)
            # return false if @on_demand_import

            @credential.import_shipped_having_tracking && !order_tracking_number(order).present?
          end

          def destroy_nil_import_items
            ImportItem.where(store_id: @store.id, order_import_summary_id: nil).destroy_all
          rescue StandardError
            nil
          end
        end
      end
    end
  end
end
