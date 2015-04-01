module Groovepacker
  module Store
    module Updaters
      module ShipstationRest
        class ProductsUpdater < Groovepacker::Store::Updaters::Updater
          def update_all
            result = {
              update_status: true,
              message: ""
            }

            order_count = 0
            product_count = 0
            
            handler = self.get_handler
            credential = handler[:credential]
            client = handler[:store_handle]
            errors = []
            import_item = handler[:import_item]

            import_item.status = 'in_progress'
            import_item.current_increment_id = ''
            import_item.success_imported = 0
            import_item.previous_imported = 0
            import_item.current_order_items = -1
            import_item.current_order_imported_item = -1
            import_item.to_import = 0
            import_item.save

            statuses = ["awaiting_shipment", "on_hold"]
            if credential.warehouse_location_update
              shipstation_orders = []
              statuses.each do |status|
                response = client.get_orders(
                  status, 
                  nil
                )
                shipstation_orders = shipstation_orders + response["orders"] unless response["orders"].nil?
              end
                
              
              puts shipstation_orders.inspect
              import_item.to_import = shipstation_orders.length unless shipstation_orders.nil?
              import_item.save
              shipstation_orders.each do |order|
                import_item.current_increment_id = order['orderNumber']
                import_item.current_order_items = order["items"].length
                import_item.current_order_imported_item = 0
                import_item.save
                order_item_update_count = 0
                order["items"].each_with_index do |order_item, index|
                  import_item.current_order_imported_item = index + 1
                  import_item.save

                  unless ProductSku.where(sku: order_item["sku"]).empty?
                    product = ProductSku.where(sku: order_item["sku"]).first.product
                    unless product.nil?
                      update_response = update_product(product, client, credential, order)
                      result[:update_status] &= update_response[:update_status]
                      order_item_update_count = order_item_update_count + update_response[:order_count]
                      errors << update_response[:message] unless update_response[:update_status]
                    end
                  end
                end

                if order_item_update_count > 0
                  import_item.success_imported = import_item.success_imported + 1
                else
                  import_item.previous_imported = import_item.previous_imported + 1
                end
                import_item.save
              end
            end

            if result[:update_status]
              import_item.status = 'completed'
            else
              import_item.status = 'failed'
              import_item.message = errors.join(", ")
              result[:message] = errors.join(", ")
            end
            import_item.save
            result
          end

          def update_single(product, order_id)
            puts "Updating product"
            handler = self.get_handler
            credential = handler[:credential]
            client = handler[:store_handle]
            result = self.build_result
            puts "sku matched"

            #update inventory warehouse's primary location
            shipstation_order = client.get_order(order_id)
            update_product(product, client, credential, shipstation_order)
          end

          private

          def update_product(product, client, credential, shipstation_order)
            result = {
              update_status: true,
              order_count: 0,
              message: ''
            }

            begin
              #update warehouse location of an SKU.
              if shipstation_order["orderStatus"] == 'awaiting_shipment' ||
                shipstation_order["orderStatus"] == 'on_hold'
                shipstation_order["items"].each_with_index do |item, index|
                  if item["sku"] == product.primary_sku && 
                    !product.primary_warehouse.nil? && 
                    product.primary_warehouse.location_primary != nil &&
                    product.primary_warehouse.location_primary != '' &&
                    item["warehouseLocation"] != product.primary_warehouse.location_primary
                    #update location only if the above conditions are satisfied
                    item["warehouseLocation"] = product.primary_warehouse.location_primary
                    shipstation_order["items"][index] = item
                    client.update_order(shipstation_order["orderId"], shipstation_order)
                    result[:order_count] = result[:order_count] + 1
                  end
                end
              end
            rescue Exception => ex
              result[:update_status] = false
              result[:message] = ex.message
            end

            result         
          end

        end
      end
    end
  end
end