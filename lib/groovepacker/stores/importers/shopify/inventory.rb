module Groovepacker
  module Stores
    module Importers
      module Shopify
        class Inventory < Groovepacker::Stores::Importers::Importer
          include ProductsHelper

          def pull_inventories
            init_credential_and_client(handler)

            #products = Product.where(store_id: credential.store_id)
            products = Product.joins(:sync_option).where("sync_with_shopify=true and (shopify_product_id IS NOT NULL or store_product_id IS NOT NULL)")
            
            (products||[]).each do |product|
              begin
                inv_wh = product.product_inventory_warehousess.first
                @sync_optn = product.sync_option
                shopify_product_id = @sync_optn.shopify_product_id
                shopify_product_sku = @sync_optn.shopify_product_sku
                next if shopify_product_id.blank? || shopify_product_sku.blank?
                shopify_product_inv = @client.get_variants(shopify_product_id, shopify_product_sku)
                unless shopify_product_inv.blank?
                  update_product_inv_for_sync_option(product, shopify_product_inv, inv_wh)
                end
              rescue Exception => ex
                return ex
              end
            end
          end

          private
            def init_credential_and_client(handler)
              @credential = handler[:credential]
              @client = handler[:store_handle]
            end

            def update_product_inv_for_sync_option(product, shopify_product_inv, inv_wh)
              if @sync_optn.shopify_product_sku==shopify_product_inv["sku"]
                inv_wh.quantity_on_hand = shopify_product_inv["inventory_quantity"].try(:to_i) + inv_wh.allocated_inv.to_i
                inv_wh.save!
              end
            end

            def eligible_for_sync(bc_product)
              return @sync_optn.sync_with_bc && @sync_optn.bc_product_id && @sync_optn.bc_product_sku && bc_product["id"]
            end
        end
      end
    end
  end
end
