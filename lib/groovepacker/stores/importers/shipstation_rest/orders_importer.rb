module Groovepacker
  module Stores
    module Importers
      module ShipstationRest
        include ProductsHelper
        class OrdersImporter < Groovepacker::Stores::Importers::Importer
          attr_accessor :importing_time, :quick_importing_time, :import_from, :import_date_type
          include ProductsHelper

          def import
            #this method is initializing following objects: @credential, @client, @import_item, @result
            init_common_objects
            set_import_date_and_type
            unless statuses.empty? && gp_ready_tag_id == -1
              initialize_orders_import
            else
              set_status_and_msg_for_skipping_import
            end
            @result
          end

          def initialize_orders_import
            response = get_orders_response
            return @result if response["orders"].blank?
            shipments_response = @client.get_shipments(import_from-1.days)
            @result[:total_imported] = response["orders"].length
            initialize_import_item
            import_orders_from_response(response, shipments_response)
            if @result[:status]
              @credential.last_imported_at = importing_time || @credential.last_imported_at
              @credential.quick_import_last_modified = quick_importing_time || @credential.last_imported_at
              @credential.save
            end
          end

          def import_single_order(order_no)
            init_common_objects
            initialize_import_item
            @scan_settings = ScanPackSetting.last
            on_demand_logger = Logger.new("#{Rails.root}/log/on_demand_import_#{Apartment::Tenant.current}.log")
            on_demand_logger.info("=========================================")
            on_demand_logger.info("StoreId: #{@credential.store.id}")
            response, shipments_response = @client.get_order_on_demand(order_no)
            response, shipments_response = @client.get_order_by_tracking_number(order_no) if response["orders"].blank? and @scan_settings.scan_by_tracking_number
            import_orders_from_response(response, shipments_response)
            Order.emit_data_for_on_demand_import(response, order_no)
            @import_item.destroy
          end

          def import_orders_from_response(response, shipments_response)
            check_or_assign_import_item
            response["orders"].each do |order|
              @import_item.reload
              break if @import_item.status == 'cancelled'
              @import_item.update_attributes(:current_increment_id => order["orderNumber"], :current_order_items => -1, :current_order_imported_item => -1)
              shipstation_order = find_or_init_new_order(order)
              ActiveRecord::Base.transaction { import_order_form_response(shipstation_order, order, shipments_response) }
              sleep 0.3
            end
          end

          def import_order_form_response(shipstation_order, order, shipments_response)
            if shipstation_order.present? && !shipstation_order.persisted?
              import_order(shipstation_order, order)
              tracking_info = shipments_response.find {|shipment| shipment["orderId"]==order["orderId"]} || {}
              shipstation_order.tracking_num = tracking_info["trackingNumber"]
              import_order_items(shipstation_order, order)
              return unless shipstation_order.save
              update_order_activity_log(shipstation_order)
              remove_gp_tags_from_ss(order)
            else
              @import_item.update_attributes(previous_imported: @import_item.previous_imported+1)
              @result[:previous_imported] = @result[:previous_imported] + 1
            end
          end

          def import_order(shipstation_order, order)
            shipstation_order.attributes = {  increment_id: order["orderNumber"], store_order_id: order["orderId"],
                                              order_placed_time: order["orderDate"], email: order["customerEmail"],
                                              shipping_amount: order["shippingAmount"], order_total: order["amountPaid"]
                                            }
            shipstation_order = init_shipping_address(shipstation_order, order)
            shipstation_order = import_notes(shipstation_order, order)
            shipstation_order.weight_oz = order["weight"]["value"] rescue nil
            shipstation_order.save
          end

          def import_order_items(shipstation_order, order)
            return if order["items"].nil?
            @import_item.update_attributes(current_order_items: order["items"].length, current_order_imported_item: 0)
            order["items"].each do |item|
              product = product_importer_client.find_or_create_product(item)
              import_order_item(item, shipstation_order, product)
              @import_item.current_order_imported_item = @import_item.current_order_imported_item + 1
            end
            shipstation_order.save
            @import_item.save
          end

          def import_order_item(item, shipstation_order, product)
            order_item = shipstation_order.order_items.build(product_id: product.id)
            order_item.qty = item["quantity"]
            order_item.price = item["unitPrice"]
            order_item.row_total = item["unitPrice"].to_f * item["quantity"].to_f
          end

          private
            def statuses
              @statuses ||= @credential.get_active_statuses
            end

            def set_import_date_and_type
              case @import_item.import_type
              when 'deep'
                self.import_from = DateTime.now - (@import_item.days.to_i.days rescue 1.days)
              when 'quick'
                quick_import_date = @credential.quick_import_last_modified
                self.import_from = quick_import_date.blank? ? DateTime.now-1.days : quick_import_date
              else
                last_imported_at = @credential.last_imported_at
                self.import_from = last_imported_at.blank? ? DateTime.now-1.weeks : last_imported_at-@credential.regular_import_range.days
              end
              set_import_date_type
            end

            def set_import_date_type
              date_types = {"deep" => "modified_at", "quick" => "modified_at"}
              self.import_date_type = date_types[@import_item.import_type] || "created_at"
            end

            def ss_tags_list
              @ss_tags_list ||= @client.get_tags_list
            end

            def gp_ready_tag_id
              @gp_ready_tag_id ||= ss_tags_list[@credential.gp_ready_tag_name] || -1
            end

            def gp_imported_tag_id
              @gp_imported_tag_id ||= ss_tags_list[@credential.gp_imported_tag_name] || -1
            end

            def init_shipping_address(shipstation_order, order)
              return shipstation_order if order["shipTo"].blank?
              address = order["shipTo"]
              split_name = address["name"].split(' ') rescue ' '
              shipstation_order.attributes = {
                      lastname: split_name.pop, firstname: split_name.join(' '),
                      address_1: address["street1"], address_2: address["street2"],
                      city: address["city"], state: address["state"],
                      postcode: address["postalCode"], country: address["country"] }
              return shipstation_order
            end

            def import_notes(shipstation_order, order)
              shipstation_order.notes_internal = order["internalNotes"] if @credential.shall_import_internal_notes
              shipstation_order.customer_comments = order["customerNotes"] if @credential.shall_import_customer_notes
              return shipstation_order
            end

            def get_orders_response
              response = {"orders" => nil}
              response = fetch_orders_if_import_type_is_not_tagged(response)
              response = fetch_tagged_orders(response)
              return response
            end

            def fetch_orders_if_import_type_is_not_tagged(response)
              return response unless @import_item.import_type != 'tagged'
              statuses.each do |status|
                status_response = @client.get_orders(status, import_from, import_date_type)
                response = get_orders_from_union(response, status_response)
              end
              self.importing_time = DateTime.now
              self.quick_importing_time = DateTime.now
              return response
            end

            def fetch_tagged_orders(response)
              return response unless gp_ready_tag_id != -1
              tagged_response = @client.get_orders_by_tag(gp_ready_tag_id)
              #perform union of orders
              response = get_orders_from_union(response, tagged_response)
              return response
            end

            def get_orders_from_union(response, tagged_or_status_response)
              response["orders"] = response["orders"].blank? ? tagged_or_status_response["orders"] : (response["orders"] | tagged_or_status_response["orders"])
              return response
            end

            def set_status_and_msg_for_skipping_import
              @result[:status] = false
              @result[:messages].push(
                'All import statuses disabled and no GP Ready tags found. Import skipped.')
              @import_item.message = 'All import statuses disabled and no GP Ready tags found. Import skipped.'
              @import_item.save
            end

            def find_or_init_new_order(order)
              shipstation_order = Order.find_by_store_id_and_increment_id(@credential.store_id, order["orderNumber"])
              return if shipstation_order && (shipstation_order.status=="scanned" || shipstation_order.status=="cancelled")
              if @import_item.import_type == 'quick' && shipstation_order
                shipstation_order.destroy
                shipstation_order = nil
              end
              init_new_order_if_required(shipstation_order, order)
            end

            def init_new_order_if_required(shipstation_order, order)
              if shipstation_order.blank?
                shipstation_order = Order.new(store_id: @store.id)
              elsif (order["tagIds"]||[]).include?(gp_ready_tag_id)
                # in order to adjust inventory on deletion of order assign order status as 'cancelled'
                shipstation_order.status = 'cancelled'
                shipstation_order.save
                shipstation_order.destroy
                shipstation_order = Order.new(store_id: @store.id)
              end
              shipstation_order
            end

            def update_order_activity_log(shipstation_order)
              shipstation_order.addactivity("Order Import", @credential.store.name+" Import")
              shipstation_order.order_items.each do |item|
                update_activity_for_single_item(shipstation_order, item)
              end
              shipstation_order.set_order_status
              @result[:success_imported] = @result[:success_imported] + 1
              @import_item.update_attributes(success_imported: @result[:success_imported])
            end

            def update_activity_for_single_item(shipstation_order, item)
              if item.qty.blank? || item.qty<1
                shipstation_order.addactivity("Item with SKU: #{item.product.primary_sku} had QTY of 0 and was removed:", "#{@credential.store.name} Import")
                item.destroy
              elsif item.product.try(:primary_sku).present?
                shipstation_order.addactivity("Item with SKU: #{item.product.primary_sku} Added", "#{@credential.store.name} Import")
              end
            end

            def remove_gp_tags_from_ss(order)
              return unless gp_ready_tag_id != -1 && (order["tagIds"]||[]).include?(gp_ready_tag_id)
              @client.remove_tag_from_order(order["orderId"], gp_ready_tag_id)
              @client.add_tag_to_order(order["orderId"], gp_imported_tag_id) if gp_imported_tag_id != -1
            end

            def product_importer_client
              @product_importer_client ||= Groovepacker::Stores::Context.new(
                              Groovepacker::Stores::Handlers::ShipstationRestHandler.new(@credential.store))
            end

        end
      end
    end
  end
end
