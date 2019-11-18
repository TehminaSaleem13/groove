module Groovepacker
  module Stores
    module Importers
      module ShipstationRest
        include ProductsHelper
        class OrdersImporterNew < Groovepacker::Stores::Importers::Importer
          attr_accessor :importing_time, :quick_importing_time, :import_from, :import_date_type
          include ProductsHelper

          def import
            init_common_objects
            set_import_date_and_type
            unless statuses.empty? && gp_ready_tag_id == -1
              get_order_and_apply_delay
            else
              set_status_and_msg_for_skipping_import
            end
            @result
          end

          def get_order_and_apply_delay
            response = get_orders_response_count
            if response == 0
              @result[:no_order] = true 
              return @result 
            end
            @result[:total_imported] = response.to_i
            total_order = response.to_i
            @total_pages = (total_order / 100.to_f).ceil
            data = { client: @client, credential: @credential.id, result: @result, store: @store.id, import_item: @import_item.id,  import_from: self.import_from , total_pages: @total_pages, importing_time: self.importing_time, quick_importing_time: self.quick_importing_time }
            $redis.set("#{Apartment::Tenant.current}_success_import", 0)
            shipments_response = @client.get_shipments(import_from-1.days)
            $redis.set("#{Apartment::Tenant.current}_shipment_response",shipments_response)
            t = Groovepacker::Stores::Importers::ShipstationRest::OrdersImporterNew.new("a")
            if total_order <= 100
              t.delay(:queue => "#{Apartment::Tenant.current}_importing_page_1").start_worker(data, 1, Apartment::Tenant.current)
            else
              t.delay(:queue => "#{Apartment::Tenant.current}_importing_page_1").start_worker(data, 1, Apartment::Tenant.current)
              t.delay(:queue => "#{Apartment::Tenant.current}_importing_page_2").start_worker(data, 2, Apartment::Tenant.current)
            end  
          end


        def start_worker(data, page_index,name)
          get_start(data, page_index, name)
          if data[:total_pages] == 1
            after_import(data)
          elsif page_index <= data[:total_pages]
            t = Groovepacker::Stores::Importers::ShipstationRest::OrdersImporterNew.new("a")
            t.delay(:queue => "#{Apartment::Tenant.current}_importing_page_#{page_index + 2}").start_worker(data, page_index + 2, Apartment::Tenant.current)
          else
            after_import(data)
          end       
        end

        def get_start(data, page_index,name)
          Apartment::Tenant.switch name
          @store = Store.find(data[:store])
          @credential = ShipstationRestCredential.find(data[:credential])
          @result = data[:result]
          @import_item = ImportItem.find(data[:import_item])
          @client = data[:client]
          @total_pages = data[:total_pages]
          import_from = data[:import_from]
          import_date_type = data[:import_date_type]
          @statuses ||= @credential.get_active_statuses
          response = get_orders_response_v2(page_index, @statuses, import_from, set_import_date_type) 
          if !response["orders"].blank?
            initialize_orders_import(response) 
            if @total_pages == page_index
              @credential.download_ss_image = false
              @credential.save
            end  
          end
        end

        def after_import(data)
          all_delayed = Delayed::Job.where("queue LIKE ?","%#{Apartment::Tenant.current}_importing_page%" ).where(failed_at: nil).count
          if all_delayed <= 1
            importing_time = data[:importing_time]
            quick_importing_time = data[:quick_importing_time]
            if @result[:status] && @import_item != 'tagged'
              @credential.last_imported_at = importing_time || @credential.last_imported_at
              @credential.quick_import_last_modified = quick_importing_time || @credential.last_imported_at
              @credential.save
            end          
            update_orders_status
            destroy_nil_import_items
            ids = OrderItemKitProduct.select("MIN(id) as id").group('product_kit_skus_id, order_item_id').collect(&:id) rescue nil
            OrderItemKitProduct.where("id NOT IN (?)",ids).destroy_all
            @import_item.update_attributes(status: 'completed') if @import_item.status != 'cancelled' 
            emit_record
          end
        end

          def initialize_orders_import(response)
            response['orders'] = response['orders'].sort_by { |h| h["orderDate"].split('-') } rescue response['orders']
            initialize_import_item
            begin
              shipments_response =  eval $redis.get("#{Apartment::Tenant.current}_shipment_response")  rescue  []
            rescue 
              shipments_response = []
            end
           
            import_orders_from_response(response, shipments_response)
          end

          def import_single_order(order_no)
            init_common_objects
            initialize_import_item
            @scan_settings = ScanPackSetting.last
            response, shipments_response = @client.get_order_on_demand(order_no, @import_item)
            response, shipments_response = @client.get_order_by_tracking_number(order_no) if response["orders"].blank? and @scan_settings.scan_by_tracking_number
            import_orders_from_response(response, shipments_response)
            Order.emit_data_for_on_demand_import_v2(response, order_no)
            time_zone = GeneralSetting.last.time_zone.to_i
            od_tz = @import_item.created_at + time_zone
            od_utc = @import_item.created_at
            status_set_in_gp = [] 
            status_set_in_gp << "Awaiting Shipment"  if @credential.shall_import_awaiting_shipment
            status_set_in_gp <<  "Pending Fulfillment" if @credential.shall_import_pending_fulfillment
            status_set_in_gp << "Shipped" if @credential.shall_import_shipped
            if response["orders"].blank?
              log = { "Tenant" => "#{Apartment::Tenant.current}","Order number"  => "#{order_no}", "Order Status Settings" => "#{status_set_in_gp}", "Order Date Settings" => "#{@credential.regular_import_range} days", "Timestamp of the OD import (in tenants TZ)" => "#{od_tz}", "Timestamp of the OD import (UTC)" => "#{od_utc}" , "Type" => "import failure" } 
            else
              order_in_gp = Order.find_by_increment_id(order_no)
              order_in_gp = Order.find_by_tracking_num(order_no)  if order_in_gp.nil?
              log = { "Tenant" => "#{Apartment::Tenant.current}","Order number"  => "#{order_no}", "Order Create Date" => "#{order_in_gp.try(:created_at)}", "Order Modified Date" => "#{order_in_gp.try(:updated_at)}", "Order Status (the status in the OrderManager)" =>"#{(response["orders"].first["orderStatus"] rescue nil)}","Order Status Settings" => "#{status_set_in_gp}", "Order Date Settings" => "#{@credential.regular_import_range} days", "Timestamp of the OD import (in tenants TZ)" => "#{od_tz}", "Timestamp of the OD import (UTC)" => "#{od_utc}", "Type" => "import success" } 
            end
            summary = CsvImportSummary.find_or_create_by_log_record(log.to_json)
            summary.file_name =  ""
            summary.import_type = "On demand import"
            summary.save
            @import_item.destroy
            destroy_nil_import_items
          end

          def import_orders_from_response(response, shipments_response)
            # check_or_assign_import_item
            @is_download_image = @store.shipstation_rest_credential.download_ss_image
            response["orders"].each do |order|
              import_item_fix
              break if @import_item.blank? || @import_item.try(:status) == 'cancelled'
              begin
                @import_item.update_attributes(:current_increment_id => order["orderNumber"], :current_order_items => -1, :current_order_imported_item => -1)
                shipstation_order = find_or_init_new_order(order)
                import_order_form_response(shipstation_order, order, shipments_response) 
              rescue Exception => e
              end
              break if Rails.env == "test"
              sleep 0.3
            end
          end

          def import_order_form_response(shipstation_order, order, shipments_response)
            if shipstation_order.present? && !shipstation_order.persisted?
              import_order(shipstation_order, order)
              tracking_info = (shipments_response || []).find {|shipment| shipment["orderId"]==order["orderId"] && shipment["voided"]==false} || {} rescue {}
              if tracking_info.blank?
                response = @client.get_shipments_by_orderno(order["orderNumber"])
                tracking_info = {}
                if response.present?
                  response.each do |shipment|
                    tracking_info = shipment if shipment["voided"] == false
                  end
                end
              end
              shipstation_order = Order.find_by_id(shipstation_order.id) if shipstation_order.frozen?
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
              if @is_download_image
                images = product.product_images
                product.product_images.create(image: item["imageUrl"]) if item["imageUrl"].present? && images.blank?
              end
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
              when 'regular', 'quick'
                @import_item.update_attribute(:import_type, "quick")
                quick_import_date = @credential.quick_import_last_modified
                self.import_from = quick_import_date.blank? ? DateTime.now-5.days : quick_import_date
              when 'tagged'
                @import_item.update_attribute(:import_type, "tagged")
                self.import_from = DateTime.now-1.weeks
              when 'from_create_date'
                @import_item.update_attribute(:import_type, "regular")
                quick_import_date = @credential.quick_import_last_modified
                self.import_from = quick_import_date.blank? ? DateTime.now-5.days : quick_import_date 
              else
                @import_item.update_attribute(:import_type, "regular")
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
              @gp_ready_tag_id ||= ss_tags_list[@credential.gp_ready_tag_name.downcase] || -1
            end

            def gp_imported_tag_id
              @gp_imported_tag_id ||= ss_tags_list[@credential.gp_imported_tag_name.downcase] || -1
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

            def get_orders_response_v2(page_index, statuses, import_from, import_date_type)
              response = {"orders" => nil}
              response = fetch_orders_if_import_type_is_not_tagged_v2(response, page_index, statuses, import_from, import_date_type)
              response = fetch_tagged_orders(response,page_index)
              return response
            end

            def get_orders_response_count
              total_response_count  = 0
              total_response_count = fetch_orders_count_if_import_type_is_not_tagged(total_response_count)
              total_tagged_order_count = fetch_tagged_orders_count(total_response_count, @import_item.import_type, statuses)
              total_response_count = total_response_count + total_tagged_order_count
              return total_response_count
            end

            def fetch_orders_count_if_import_type_is_not_tagged(total_response_count)
              return total_response_count unless @import_item.import_type != 'tagged'
              statuses.each do |status|
                status_response = @client.get_orders_count_ss(status, import_from, import_date_type)
                total_response_count = total_response_count + status_response
              end
              self.importing_time = DateTime.now
              self.quick_importing_time = DateTime.now
              return total_response_count
            end

            def fetch_orders_if_import_type_is_not_tagged_v2(response, page_index, statuses, import_from, import_date_type)
              return response unless @import_item.import_type != 'tagged'
              statuses.each do |status|
                status_response = @client.get_orders_v2(status, import_from, import_date_type, page_index)
                response = get_orders_from_union(response, status_response)
              end
              return response
            end

            def fetch_tagged_orders(response, page_index)
              return response unless gp_ready_tag_id != -1
              tagged_response = @client.get_orders_by_tag_v2(gp_ready_tag_id, page_index)
              response = get_orders_from_union(response, tagged_response)
              return response
            end

            def fetch_tagged_orders_count(total_response_count, import_type, statuses)
              return total_response_count unless gp_ready_tag_id != -1
              page_index = 1
              total_response_count = @client.get_orders_count_by_tag_v2(gp_ready_tag_id, page_index, import_type, statuses)
              return total_response_count
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
              @result[:no_order] = true
            end

            def find_or_init_new_order(order)
              if @credential.allow_duplicate_order == true
                shipstation_order = Order.find_by_store_id_and_increment_id_and_store_order_id(@credential.store_id, order["orderNumber"], order["orderId"])
              else
                shipstation_order = Order.find_by_store_id_and_increment_id(@credential.store_id, order["orderNumber"])
              end
              return if shipstation_order && (shipstation_order.status=="scanned" || shipstation_order.status=="cancelled" || shipstation_order.order_items.map(&:scanned_status).include?("partially_scanned") || shipstation_order.order_items.map(&:scanned_status).include?("scanned"))
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
              v = $redis.get("#{Apartment::Tenant.current}_success_import").to_i  + 1
              $redis.set("#{Apartment::Tenant.current}_success_import", v)
              @result[:success_imported] =  $redis.get("#{Apartment::Tenant.current}_success_import").to_i 
              @import_item.update_attributes(success_imported: @result[:success_imported]) 
            end

            def update_activity_for_single_item(shipstation_order, item)
              if item.qty.blank? || item.qty<1
                shipstation_order.addactivity("Item with SKU: #{item.product.primary_sku} had QTY of 0 and was removed:", "#{@credential.store.name} Import")
                item.destroy
              elsif item.product.try(:primary_sku).present?
                shipstation_order.addactivity("QTY #{item.qty} of item with SKU: #{item.product.primary_sku} Added", "#{@credential.store.name} Import")
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

            def destroy_nil_import_items
              ImportItem.where(:store_id => @store.id , :order_import_summary_id => nil).destroy_all rescue nil
              # ImportItem.where("status IS NULL").destroy_all
            end

        end
      end
    end
  end
end
