module Groovepacker
  module Store
    module Updaters
      module ShipstationRest
        class ProductsUpdater < Groovepacker::Store::Updaters::Updater
          def update
            {}
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
                shipstation_order = client.get_order(order_item.order.store_order_id)
                #update warehouse location of an SKU.
                puts "updating location"
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
      end
    end
  end
end