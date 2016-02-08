module Groovepacker
  module Stores
    module Exporters
      module Shopify
        class Inventory < Groovepacker::Stores::Importers::Importer
          include ProductsHelper

          def push_inventories
            @credential = handler[:credential]
            @client = handler[:store_handle]
            
            products = Product.joins(:sync_option).where("sync_with_shopify=true and (shopify_product_variant_id IS NOT NULL or store_product_id IS NOT NULL)")
            
            (products||[]).each do |product|
              begin
                inv_wh = product.product_inventory_warehousess.last
                inv_level = (inv_wh.available_inv || 0) rescue 0
                inv_lavel = (inv_level < 0) ? 0 : inv_level
                attrs = {
													variant: { inventory_quantity: inv_level }
												}
												
                @sync_optn = product.sync_option
                next if @sync_optn.shopify_product_variant_id.blank?
                
                update_inv_on_shopify_for_sync_option(product, @sync_optn, attrs)
              rescue Exception => ex
                return ex
              end
            end
          end

          private
            def update_inv_on_shopify_for_sync_option(product, sync_option, attrs)
              shopify_product = @client.update_inventory(sync_option, attrs)
            end
            
        end
      end
    end
  end
end
