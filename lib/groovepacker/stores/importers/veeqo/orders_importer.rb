# frozen_string_literal: true

module Groovepacker
  module Stores
    module Importers
      module Veeqo
        class OrdersImporter < Importer
          include ProductsHelper

          def import
            init_common_objects
            @import_item.update(updated_orders_import: 0)
            initialize_orders_import
            update_orders_status
            destroy_nil_import_items
            @result
          end

          def initialize_orders_import
            Tenant.save_se_import_data("========Veeqo Regular Import Started UTC: #{Time.current.utc} TZ: #{Time.current}")
            begin
              OrderImportSummary.top_summary.emit_data_to_user(true)
            rescue StandardError
              nil
            end
            return @result unless @import_item.present?

            @import_item.update_column(:importer_id, @worker_id)
            response = get_orders_response

            response_orders = response['orders'].select { |o| o['allocations'].count <= 1 }
            multi_allocation_orders = response['orders'].select { |o| o['allocations'].count > 1 }
            split_orders_by_allocation(response_orders, multi_allocation_orders)

            @result[:total_imported] = response_orders.nil? ? 0 : response_orders.length
            initialize_import_item
            return @result if response_orders.nil? || response_orders.blank? || response_orders.first.nil?

            response_orders = begin
                                    response_orders.sort_by { |h| Time.zone.parse(h['updated_at']) }
                                  rescue StandardError
                                    response_orders
                                  end

            ImportItem.where(store_id: @store.id).where.not(id: @import_item).update_all(status: 'cancelled')
            Groovepacker::Stores::Importers::LogglyLog.log_orders_response(response_orders, @store, @import_item) if current_tenant_object&.loggly_veeqo_imports

            response_orders.each do |order|
              break if import_should_be_cancelled

              import_single_order(order) if order.present?
              @credential.update(last_imported_at: Time.zone.parse(order['updated_at']))
            end
            add_deleted_merged_or_split_orders_log
            send_sku_not_found_report_during_order_import
            Tenant.save_se_import_data("========Veeqo Regular Import Finished UTC: #{Time.current.utc} TZ: #{Time.current}", '==Import Item', @import_item.as_json)
          end

          def ondemand_import_single_order(order_number, user_id)
            @on_demand_import = true
            @ondemand_user_name = ondemand_user(user_id)
            init_common_objects
            response = @client.get_single_order(order_number, @import_item)
            response_orders = response['orders'].select { |o| o['allocations'].count <= 1 }
            multi_allocation_orders = response['orders'].select { |o| o['allocations'].count > 1 }
            split_orders_by_allocation(response_orders, multi_allocation_orders)

            response_orders.each do |order|
              import_single_order(order) if order.present?
            end
            add_deleted_merged_or_split_orders_log
            send_sku_not_found_report_during_order_import
            begin
              @import_item.destroy
              destroy_nil_import_items
            rescue StandardError
              nil
            end
          end

          private

          def split_orders_by_allocation(response_orders, multi_allocation_orders)
            if multi_allocation_orders.present? && @credential.allow_duplicate_order
              multi_allocation_orders.each do |o|
                o['allocations'].each do |a|
                  order_response = o.dup
                  order_response['allocations'] = [a]
                  response_orders << order_response
                end
              end
            end
          end

          def add_deleted_merged_or_split_orders_log
            if @deleted_merged_orders.count > 0
              add_action_log('List of Deleted Orders', 'Veeqo Order Import - Merged Order', @deleted_merged_orders, @deleted_merged_orders.count)
            end

            if @deleted_split_orders.count > 0
              add_action_log('List of Deleted Orders', 'Veeqo Order Import - Split Order', @deleted_split_orders, @deleted_split_orders.count)
            end
          end

          def statuses
            @statuses ||= @credential.get_active_statuses
          end

          def get_orders_response
            response = { 'orders' => nil }

            statuses.each do |status|
              status_response = @client.orders(@import_item, status)
              response = get_orders_from_union(response, status_response)
            end
            response
          end

          def get_orders_from_union(response, status_response)
            response['orders'] =
              response['orders'].blank? ? status_response['orders'] : (response['orders'] | status_response['orders'])
            response
          end

          def import_single_order(order)
            @import_item.update(current_increment_id: order['number'], current_order_items: -1,
                                current_order_imported_item: -1)
            update_import_count('success_updated') && return if skip_the_order?(order)

            order_in_gp_present = false
            allocation_id = order['allocations'].dig(0, 'id')
            order_in_gp = search_veeqo_order_in_db(set_order_number(order), order['id'], allocation_id)
            return if handle_cancelled_order(order_in_gp)
            return if handle_merged_order(order, allocation_id)
            return if order['status'] == 'awaiting_stock'
            handle_split_order(order)
            veeqo_shopify_order_import(order_in_gp_present, order_in_gp, order)
          end

          def handle_split_order(order)
            handle_order_deletion(order, 'split_order')
          end

          def handle_merged_order(order, allocation_id = nil)
            return false unless order['merged_to_id'].present?

            handle_order_deletion(order, 'merged_order', allocation_id)
          end

          def handle_order_deletion(order, type, allocation_id = nil)
            orders = Order.where.not(status: 'scanned')
            order_record = case type
                           when 'merged_order'
                             orders.find_by(store_id: @credential.store_id, store_order_id: order['id'], veeqo_allocation_id: allocation_id)
                           when 'split_order'
                             orders.find_by(store_id: @credential.store_id, store_order_id: order['id'], veeqo_allocation_id: nil)
                           end

            if order_record && type == 'merged_order'
              @deleted_merged_orders << order_record.increment_id
            elsif order_record && type == 'split_order'
              @deleted_split_orders << order_record.increment_id
            end
            order_record&.destroy
            true
          end

          def search_veeqo_order_in_db(order_number, store_order_id, allocation_id = nil)
            if @credential.allow_duplicate_order == true
              Order.find_by_store_id_and_increment_id_and_store_order_id_and_veeqo_allocation_id(@credential.store_id, order_number, store_order_id, allocation_id)
            else
              Order.find_by_store_id_and_increment_id_and_veeqo_allocation_id(@credential.store_id, order_number, allocation_id)
            end
          end

          def destroy_nil_import_items
            ImportItem.where(store_id: @store.id, order_import_summary_id: nil).destroy_all
          rescue StandardError
            nil
          end

          def import_order(veeqo_order, order)
            # veeqo_order.tags = order['tags']
            veeqo_order.increment_id = set_order_number(order)
            veeqo_order.store_order_id = order['id'].to_s
            veeqo_order.veeqo_allocation_id = order['allocations'].dig(0, 'id')
            veeqo_order.order_placed_time = Time.zone.parse(order['created_at'])
            # add order custmor info using separate method
            veeqo_order = add_customer_info(veeqo_order, order)
            # add order shipping address using separate method
            veeqo_order = add_order_shipping_address(veeqo_order, order)
            # add notes
            veeqo_order = import_notes(veeqo_order, order)
            # update shipping_amount and order weight
            # veeqo_order = update_shipping_amount_and_weight(veeqo_order, order)
            veeqo_order.order_total = order['total_price']&.to_f
            veeqo_order.last_modified = Time.zone.parse(order['updated_at'])
            veeqo_order.tracking_num = get_tracking_number(order)
            veeqo_order.job_timestamp = Time.current.strftime('%Y-%m-%d %H:%M:%S.%L')
            veeqo_order
          end

          def set_order_number(order)
            @credential&.use_veeqo_order_id ? order['id'].to_s : order['number']
          end

          def get_tracking_number(order)
            order.dig('allocations', 0, 'shipment', 'tracking_number', 'tracking_number')
          rescue StandardError => e
            nil
          end

          def import_notes(veeqo_order, order)
            if @credential.shall_import_internal_notes && order['employee_notes'].present?
              veeqo_order.notes_internal = order['employee_notes'].map do |note|
                note['text']
              end.join(', ')
            end
            if @credential.shall_import_customer_notes && order['customer_note'].present?
              veeqo_order.customer_comments = order.dig('customer_note',
                                                        'text')
            end
            veeqo_order
          end

          def import_shipped_having_tracking
            @import_shipped_having_tracking ||= @credential.import_shipped_having_tracking
          end

          def import_veeqo_order_item(veeqo_order, order)
            order_allocations = order['allocations'].dig(0, 'line_items')
            line_items = order_allocations.present? ? order_allocations : order['line_items']
            return if line_items.blank?

            @import_item.current_order_items = line_items.length
            @import_item.current_order_imported_item = 0
            @import_item.save!
            line_items.each do |item|
              order_item = import_order_item(item)
              @import_item.update!(current_order_imported_item: @import_item.current_order_imported_item + 1)
              product = Product.joins(:product_skus).find_by(product_skus: { sku: item['sellable']['sku_code'] }) || import_order_items(
                item, set_order_number(order)
              )
              if product.present?
                order_item.product = product
                veeqo_order.order_items << order_item
              else
                on_demand_logger = Logger.new("#{Rails.root.join("log/#{@store.store_type.downcase}_missing_product_import_order_item_#{Apartment::Tenant.current}.log")}")
                log = { order_number: veeqo_order.increment_id, Time: Time.zone.now, shop_order_item: item,
                        product: }
                on_demand_logger.info(log)
              end
            end

            return unless veeqo_order.order_items.present?

            veeqo_order.save!
            veeqo_order
          end

          def import_order_items(item, order_number)
            if check_shopify_as_a_product_source
              fetch_and_import_shopify_product(item['sellable']['sku_code'], item, order_number)
            else
              veeqo_context.import_veeqo_single_product(item)
            end
          end

          def import_order_item(line_item)
            row_total = line_item['sellable']['price'].to_f * line_item['quantity'].to_f
            OrderItem.new(qty: line_item['quantity'], price: line_item['sellable']['price'], row_total:)
          end

          def add_customer_info(veeqo_order, order)
            return veeqo_order if order['customer'].nil?

            veeqo_order.email = order['customer']['email']
            veeqo_order.firstname = order.dig('customer', 'shipping_addresses', 0, 'first_name')
            veeqo_order.lastname = order.dig('customer', 'shipping_addresses', 0, 'last_name')
            veeqo_order
          end

          def add_order_shipping_address(veeqo_order, order)
            shipping_address = order['customer']['shipping_addresses']&.first
            return veeqo_order if shipping_address.blank?

            veeqo_order.address_1 = shipping_address['address1']
            veeqo_order.address_2 = shipping_address['address2']
            veeqo_order.city = shipping_address['city']
            veeqo_order.state = shipping_address['state']
            veeqo_order.postcode = shipping_address['zip']
            veeqo_order.country = shipping_address['country']
            veeqo_order
          end

          # def update_shipping_amount_and_weight(veeqo_order, order)
          #   unless order['shipping_lines'].empty?
          #     shipping = order['shipping_lines'].first
          #     veeqo_order.shipping_amount = shipping['price'].to_f unless shipping.nil?
          #   end

          #   veeqo_order.weight_oz = (order['allocations'].first&.dig('total_weight').to_i * 0.035274) unless order['allocations'].first&.dig('total_weight').nil?
          #   veeqo_order
          # end

          def veeqo_context
            handler = Groovepacker::Stores::Handlers::VeeqoHandler.new(@store)

            Groovepacker::Stores::Context.new(handler)
          end

          def import_order_and_items(order, order_in_gp)
            # create order
            veeqo_order = order_in_gp
            Order.transaction do
              veeqo_order = import_order(veeqo_order, order)
              # import items in an order
              veeqo_order = import_veeqo_order_item(veeqo_order, order)
              return unless veeqo_order.present?

              # add order activities
              add_order_activities(veeqo_order, order)
              # update store
              veeqo_order.set_order_status
            end
          end

          def add_order_activities(veeqo_order, order)
            activity_name = @on_demand_import ? 'On Demand Order Import' : 'Order Import'
            veeqo_order.addactivity(activity_name, @credential.store.name + " Import #{@ondemand_user_name}")
            veeqo_order.order_items.each_with_index do |item, index|
              veeqo_order.addactivity("QTY #{item.qty} of item with SKU: #{item.sku} Added", "#{@store.name} Import")
            end
          end

          def skip_the_order?(order)
            # return false if @on_demand_import

            import_shipped_having_tracking && order['status'] == 'shipped' && get_tracking_number(order).nil?
          end
        end
      end
    end
  end
end
