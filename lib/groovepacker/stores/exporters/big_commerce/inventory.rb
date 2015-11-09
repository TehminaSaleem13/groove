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
              begin
                inv_wh = product.product_inventory_warehousess.last
                attrs = { inventory_level: inv_wh.available_inv }
                
                @sync_optn = product.sync_option
                bc_product_id = (@sync_optn.bc_product_id rescue nil) || product.store_product_id
                
                update_inv_on_bc_for_sync_option(product, bc_product_id, attrs)
              rescue Exception => ex
                return ex
              end
            end
          end

          private
            def update_inv_on_bc_for_sync_option(product, bc_product_id, attrs)
              bc_product = @client.product(bc_product_id)
              if bc_product["id"] && @sync_optn.bc_product_sku==bc_product["sku"]
                @client.update_product_inv("https://api.bigcommerce.com/#{@credential.store_hash}/v2/products/#{bc_product_id}", attrs)
              elsif bc_product["id"] && bc_product["skus"]
                update_product_by_bc_variants(bc_product, attrs)
              end
            end


            def update_product_by_bc_variants(bc_product, attrs)
              if @sync_optn.bc_product_sku and @sync_optn.bc_product_id
                bc_product_sku = @client.product_skus("#{bc_product["skus"]["url"]}?sku=#{@sync_optn.bc_product_sku}").first
                if bc_product_sku
                  response = @client.update_product_sku_inv("https://api.bigcommerce.com/#{@credential.store_hash}/v2/products/#{bc_product['id']}/skus/#{bc_product_sku["id"]}", attrs)
                end
              end
            end
        end
      end
    end
  end
end
