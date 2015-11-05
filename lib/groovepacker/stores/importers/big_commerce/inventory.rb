module Groovepacker
  module Stores
    module Importers
      module BigCommerce
        class Inventory < Groovepacker::Stores::Importers::Importer
          include ProductsHelper

          def pull_inventories
            @credential = handler[:credential]
            @client = handler[:store_handle]

            #products = Product.where(store_id: credential.store_id)
            products = Product.joins(:sync_option).where("sync_with_bc=true and (bc_product_id IS NOT NULL or store_product_id IS NOT NULL)")
            
            (products||[]).each do |product|
              inv_wh = product.product_inventory_warehousess.first
              @sync_optn = product.sync_option
              bc_product_id = (sync_optn.bc_product_id rescue nil) || product.store_product_id
              bc_product = @client.product(bc_product_id)
              if bc_product["id"]
                update_product_inv_for_sync_option(product, bc_product, inv_wh)
              end
            end
          end

          private
            def update_product_inv_for_sync_option(product, bc_product, inv_wh)
              if @sync_optn.bc_product_sku==bc_product["sku"]
                inv_wh.quantity_on_hand = bc_product["inventory_level"]
                inv_wh.save!
              else
                update_bc_product_variant(bc_product, inv_wh)
              end
            end

            def update_bc_product_variant(bc_product, inv_wh)
              bc_product_sku = @client.product_skus("https://api.bigcommerce.com/#{@credential.store_hash}/v2/products/#{bc_product['id']}/skus?sku=#{@sync_optn.bc_product_sku}").first
              if bc_product_sku
                inv_wh.quantity_on_hand = bc_product_sku["inventory_level"]
                inv_wh.save!
              end
            end
        end
      end
    end
  end
end
