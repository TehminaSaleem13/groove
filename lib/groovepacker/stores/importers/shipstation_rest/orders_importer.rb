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
              response = get_orders_response
              return @result if response["orders"].blank?
              shipments_response = @client.get_shipments(import_from-1.days)
              @result[:total_imported] = response["orders"].length
              initialize_import_item
              import_orders_from_response(response, shipments_response)
            else
              set_status_and_msg_for_skipping_import
            end
            @result
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
          end

          def import_orders_from_response(response, shipments_response)
            response["orders"].each do |order|
              @import_item.reload
              break if @import_item.status == 'cancelled'
              @import_item.update_attributes(:current_increment_id => order["id"], :current_order_items => -1, :current_order_imported_item => -1)
              sleep 0.5

              shipstation_order = find_or_init_new_order()
              shipstation_order = Order.find_by_store_id_and_increment_id(@credential.store_id, order["orderNumber"])
              if @import_item.import_type == 'quick' && shipstation_order && shipstation_order.status!="scanned"
                shipstation_order.destroy
                shipstation_order = nil
              end
              
              if shipstation_order.blank?
                shipstation_order = Order.new
              elsif order["tagIds"].present? && order["tagIds"].include?(gp_ready_tag_id)
                # in order to adjust inventory on deletion of order assign order status as 'cancelled'
                shipstation_order.status = 'cancelled'
                shipstation_order.save
                shipstation_order.destroy
                shipstation_order = Order.new
              end

              if shipstation_order.present? && !shipstation_order.persisted?
                ship_to = order["shipTo"]["name"].split(" ")
                import_order(shipstation_order, order)
                tracking_number = shipments_response.select {|shipment| shipment["orderId"]==order["orderId"]}.first["trackingNumber"] rescue nil
                #tracking_number = @client.get_tracking_number(order["orderId"]) if tracking_number.blank?
                shipstation_order.tracking_num = tracking_number
                unless order["items"].nil?
                  @import_item.current_order_items = order["items"].length
                  @import_item.current_order_imported_item = 0
                  @import_item.save
                  sleep 0.5
                  order["items"].each do |item|
                    order_item = OrderItem.new

                    import_order_item(order_item, item)

                    Rails.logger.info("SKU Product Id: " + item.to_s)

                    if item["sku"].nil? or item["sku"] == ''
                      # if sku is nil or empty
                      if Product.find_by_name(item["name"]).nil?
                        # if item is not found by name then create the item
                        order_item.product = create_new_product_from_order(item, @credential.store, ProductSku.get_temp_sku)
                      else
                        # product exists add temp sku if it does not exist
                        products = Product.where(name: item["name"])
                        unless contains_temp_skus(products)
                          order_item.product = create_new_product_from_order(item, @credential.store, ProductSku.get_temp_sku)
                        else
                          order_item.product = get_product_with_temp_skus(products)
                        end
                      end
                    elsif ProductSku.where(sku: item["sku"]).length == 0
                      # if non-nil sku is not found
                      product = create_new_product_from_order(item, @credential.store, item["sku"])
                      order_item.product = product
                    else
                      order_item_product = ProductSku.where(sku: item["sku"]).
                        first.product

                      unless item["imageUrl"].nil?
                        if order_item_product.product_images.length == 0
                          image = ProductImage.new
                          image.image = item["imageUrl"]
                          order_item_product.product_images << image
                        end
                      end
                      order_item_product.save
                      order_item.product = order_item_product
                    end
                    make_product_intangible(order_item.product)
                    shipstation_order.order_items << order_item
                    @import_item.current_order_imported_item = @import_item.current_order_imported_item + 1
                  end
                  @import_item.save
                  sleep 0.5
                end
                if shipstation_order.save
                  shipstation_order.addactivity("Order Import", @credential.store.name+" Import")
                  shipstation_order.order_items.each do |item|
                    if item.qty.blank? || item.qty<1
                      shipstation_order.addactivity("Item with SKU: #{item.product.primary_sku} had QTY of 0 and was removed:", "#{@credential.store.name} Import")
                      item.destroy
                      next
                    end
                    unless item.product.nil? || item.product.primary_sku.nil?
                      shipstation_order.addactivity("Item with SKU: #{item.product.primary_sku} Added", "#{@credential.store.name} Import")
                    end
                  end
                  shipstation_order.store = @credential.store
                  shipstation_order.save
                  shipstation_order.set_order_status
                  @result[:success_imported] = @result[:success_imported] + 1
                  @import_item.success_imported = @result[:success_imported]
                  @import_item.save
                  sleep 0.5
                  if gp_ready_tag_id != -1 && !order["tagIds"].nil? &&
                    order["tagIds"].include?(gp_ready_tag_id)
                    @client.remove_tag_from_order(order["orderId"], gp_ready_tag_id)
                    @client.add_tag_to_order(order["orderId"], gp_imported_tag_id) if gp_imported_tag_id != -1
                  end
                end
              else
                @import_item.previous_imported = @import_item.previous_imported + 1
                @import_item.save
                @result[:previous_imported] = @result[:previous_imported] + 1
                sleep 0.5
              end
            end
          end

          def import_order(shipstation_order, order)
            shipstation_order.attributes = {
                                              increment_id: order["orderNumber"],
                                              store_order_id: order["orderId"],
                                              order_placed_time: order["orderDate"],
                                              email: order["customerEmail"],
                                              shipping_amount: order["shippingAmount"],
                                              order_total: order["amountPaid"]
                                            }
            shipstation_order = init_shipping_address(shipstation_order, order)
            shipstation_order = import_notes(shipstation_order, order)
            shipstation_order.weight_oz = order["weight"]["value"] rescue nil
          end

          def import_order_item(order_item, item)
            order_item.qty = item["quantity"]
            order_item.price = item["unitPrice"]
            order_item.row_total = item["unitPrice"].to_f *
              item["quantity"].to_f
            order_item
          end

          def create_new_product_from_order(item, store, sku)
            #create and import product
            product = Product.new(name: item["name"], store: store, store_product_id: 0)
            product.product_skus.build(sku: sku)

            if @credential.gen_barcode_from_sku && ProductBarcode.where(barcode: sku).empty?
              product.product_barcodes.build(barcode: sku)
            end

            #Build Image
            unless item["imageUrl"].nil? || product.product_images.length > 0
              product.product_images.build(image: item["imageUrl"])
            end
            product.save
            unless item["warehouseLocation"].nil?
              product.primary_warehouse.update_column( 'location_primary', item["warehouseLocation"] )
            end

            product.set_product_status

            product
          end

          private
            def statuses
              @statuses ||= @credential.get_active_statuses
            end

            def set_import_date_and_type
              case @import_item.import_type
              when 'deep'
                self.import_from = DateTime.now - (@import_item.days.to_i.days rescue 7.days)
              when 'quick'
                quick_import_date = @credential.quick_import_last_modified
                self.import_from = quick_import_date.blank? ? DateTime.now-3.days : quick_import_date
              else
                last_imported_at = @credential.last_imported_at
                self.import_from = last_imported_at.blank? ? DateTime.now-2.weeks : last_imported_at-@credential.regular_import_range.days
              end
              set_import_date_type
            end

            def set_import_date_type
              date_types = {"deep" => "created_at", "quick" => "modified_at"}
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
                                    postcode: address["postalCode"], country: address["country"]
                                  }
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
                response["orders"] = response["orders"].blank? ? status_response["orders"] : (response["orders"] | status_response["orders"])
              end
              self.importing_time = DateTime.now - 1.day
              self.quick_importing_time = DateTime.now
              return response
            end

            def fetch_tagged_orders(response)
              return response unless @import_item.import_type != 'quick' && gp_ready_tag_id != -1
              tagged_response = @client.get_orders_by_tag(gp_ready_tag_id)
              #perform union of orders
              response["orders"] = response["orders"].blank? ? tagged_response["orders"] :
                response["orders"] | tagged_response["orders"]
              return response
            end

            def set_status_and_msg_for_skipping_import
              @result[:status] = false
              @result[:messages].push(
                'All import statuses disabled and no GP Ready tags found. Import skipped.')
              @import_item.message = 'All import statuses disabled and no GP Ready tags found. Import skipped.'
              @import_item.save
            end

            def shipstation_order = find_or_init_new_order()
              shipstation_order = Order.find_by_store_id_and_increment_id(@credential.store_id, order["orderNumber"])
              if @import_item.import_type == 'quick' && shipstation_order && shipstation_order.status!="scanned"
                shipstation_order.destroy
                shipstation_order = nil
              end
              
              if shipstation_order.blank?
                shipstation_order = Order.new
              elsif (order["tagIds"]||[]).include?(gp_ready_tag_id)
                # in order to adjust inventory on deletion of order assign order status as 'cancelled'
                shipstation_order.status = 'cancelled'
                shipstation_order.save
                shipstation_order.destroy
                shipstation_order = Order.new
              end
              return shipstation_order
            end


        end
      end
    end
  end
end
