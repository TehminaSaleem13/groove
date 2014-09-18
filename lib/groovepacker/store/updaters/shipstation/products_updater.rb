module Groovepacker
  module Store
    module Updaters
      module Shipstation
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
            warehouse = product.product_inventory_warehousess.first
            unless warehouse.nil? && warehouse.location_primary.nil?
              client.product.update_primary_location(warehouse.location_primary,
                product.product_skus.first.sku)
            end
          end
        end
      end
    end
  end
end