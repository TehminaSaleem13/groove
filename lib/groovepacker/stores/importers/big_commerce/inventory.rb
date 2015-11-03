module Groovepacker
  module Stores
    module Importers
      module BigCommerce
        class Inventory < Groovepacker::Stores::Importers::Importer
          include ProductsHelper

          def pull_inventories
            handler = self.get_handler
            credential = handler[:credential]
            client = handler[:store_handle]
            import_item = handler[:import_item]
            result = self.build_result

            products = Product.where(store_id: credential.store_id)
            
            (products||[]).each do |product|
              inv_wh = product.product_inventory_warehousess.first
              
              if product.product_type=="product"
                bc_product = client.product(product.store_product_id)
                inv_wh.quantity_on_hand = bc_product["inventory_level"]
              elsif product.product_type=="variant"
                product_sku = product.product_skus.first
                if product_sku
                  bc_product_sku = client.product_skus("https://api.bigcommerce.com/#{credential.store_hash}/v2/products/#{product.store_product_id}/skus?sku=#{product_sku.sku}").first
                  inv_wh.quantity_on_hand = bc_product_sku["inventory_level"]
                end
              end
              inv_wh.save
            end
          end

        end
      end
    end
  end
end
