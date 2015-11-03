module Groovepacker
  module Stores
    module Exporters
      module BigCommerce
        class Inventory < Groovepacker::Stores::Importers::Importer
          include ProductsHelper

          def push_inventories
            handler = self.get_handler
            credential = handler[:credential]
            client = handler[:store_handle]
            import_item = handler[:import_item]
            result = self.build_result
            products = Product.where(store_id: credential.store_id)
            
            (products||[]).each do |product|
              inv_wh = product.product_inventory_warehousess.first
              attrs = {inventory_level: inv_wh.quantity_on_hand}
              
              if product.product_type=="product"
                response = client.update_product_inv("https://api.bigcommerce.com/#{credential.store_hash}/v2/products/#{product.store_product_id}", attrs)
              elsif product.product_type=="variant"
                product_skus = product.product_skus
                (product_skus||[]).each do |sku|
                  bc_product_sku = client.product_skus("https://api.bigcommerce.com/#{credential.store_hash}/v2/products/#{product.store_product_id}/skus?sku=#{sku.sku}").first
                  response = client.update_product_sku_inv("https://api.bigcommerce.com/#{credential.store_hash}/v2/products/#{product.store_product_id}/skus/#{bc_product_sku["id"]}", attrs)
                end
              end
            end
          end

        end
      end
    end
  end
end
