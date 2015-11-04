module Groovepacker
  module Stores
    module Exporters
      module BigCommerce
        class Inventory < Groovepacker::Stores::Importers::Importer
          include ProductsHelper

          def push_inventories
            @credential = handler[:credential]
            @client = handler[:store_handle]
            
            products = Product.joins(:sync_option).where("sync_with_bc=true and (bc_product_id IS NOT NULL or store_product_id IS NOT NULL)")
            
            (products||[]).each do |product|
              inv_wh = product.product_inventory_warehousess.first
              attrs = {inventory_level: inv_wh.quantity_on_hand}
              
              sync_optn = product.sync_option
              bc_product_id = (sync_optn.bc_product_id rescue nil) || product.store_product_id
              
              update_inv_on_bc_for_sync_option(product, bc_product_id, attrs)
            end
          end

          private
            def update_inv_on_bc_for_sync_option(product, bc_product_id, attrs)
              product_skus = product.product_skus.map(&:sku)
              bc_product = @client.product(bc_product_id)
              if bc_product["id"] && product_skus.include?(bc_product["sku"])
                @client.update_product_inv("https://api.bigcommerce.com/#{@credential.store_hash}/v2/products/#{bc_product_id}", attrs)
              elsif bc_product["id"] && bc_product["skus"]
                update_product_by_bc_variants(product_skus, bc_product, attrs)
              end
            end


            def update_product_by_bc_variants(product_skus, bc_product, attrs)
              bc_product_skus = @client.product_skus(bc_product["skus"]["url"])
              (bc_product_skus||[]).each do |bc_sku|
                if product_skus.include?(bc_sku["sku"])
                  response = @client.update_product_sku_inv("https://api.bigcommerce.com/#{@credential.store_hash}/v2/products/#{bc_product['id']}/skus/#{bc_sku["id"]}", attrs)
                  break;
                end
              end
            end

        end
      end
    end
  end
end
