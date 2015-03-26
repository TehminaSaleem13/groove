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
            credential.store.products.each do |product|
              unless product.primary_warehouse.nil? ||
               product.primary_warehouse.location_primary.nil? ||
               product.primary_warehouse.location_primary == ''
               #update all orders of shipstation here which contain this product
               update_response = update_product(product, client, credential)
               result[:update_status] &= update_response[:update_status]
               order_count = order_count + update_response[:order_count]
               errors << update_response[:message] unless update_response[:status]
              end
            end

            if result[:update_status]
              result[:message] = 
                "#{order_count.to_s} order item(s) have been updated."
            else
              result[:message] = errors.join(", ")
            end

            result
          end

          def update_single(product)
            puts "Updating product"
            handler = self.get_handler
            credential = handler[:credential]
            client = handler[:store_handle]
            result = self.build_result

            #update inventory warehouse's primary location
            warehouse = product.primary_warehouse
            unless warehouse.nil? && warehouse.location_primary.nil?
              puts product.order_items.inspect
              product.order_items.each do |order_item|
                puts "order item:"
                unless order_item.order.store_order_id.nil?
                  shipstation_order = client.get_order(order_item.order.store_order_id)
                  #update warehouse location of an SKU.
                  shipstation_order["items"].each_with_index do |item, index|
                    if item["sku"] == product.primary_sku
                      puts "sku matched"
                      item["warehouseLocation"] = warehouse.location_primary
                      shipstation_order["items"][index] = item
                      client.update_order(shipstation_order["orderId"], shipstation_order)
                      client.get_order(order_item.order.store_order_id)
                    end
                  end
                end
              end
            end
          end

          private

          def update_product(product, client, credential)
            result = {
              update_status: true,
              order_count: 0,
              message: ''
            }

            product.order_items.each do |order_item|
              unless order_item.order.store_order_id.nil?
                begin
                  shipstation_order = client.get_order(order_item.order.store_order_id)
                  #update warehouse location of an SKU.
                  if shipstation_order["orderStatus"] == 'awaiting_shipment' ||
                    shipstation_order["orderStatus"] == 'on_hold'
                    shipstation_order["items"].each_with_index do |item, index|
                      if item["sku"] == product.primary_sku && 
                        item["warehouseLocation"] != product.primary_warehouse.location_primary
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
              end
            end

            result         
          end

        end
      end
    end
  end
end