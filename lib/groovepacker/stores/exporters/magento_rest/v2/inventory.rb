module Groovepacker
  module Stores
    module Exporters
      module MagentoRest
        module V2
          class Inventory < Groovepacker::Stores::Importers::Importer
            include ProductsHelper

            def push_inventories
              handler = self.get_handler
              @credential = handler[:credential]
              @client = handler[:store_handle][:handle]

              #products = Product.where(store_id: credential.store_id)
              products = Product.joins(:sync_option).where("sync_with_mg_rest=true and (mg_rest_product_id IS NOT NULL or store_product_id IS NOT NULL)")

              products.each do |product|
              	inv_wh = product.product_inventory_warehousess.first
              	@sync_optn = product.sync_option
              	next if @sync_optn.mg_rest_product_sku.blank? || @sync_optn.mg_rest_product_id.blank?
              	update_mg_rest_product_inv_for_sync_option(product, @sync_optn, inv_wh)
              end
            end

            private
              def update_mg_rest_product_inv_for_sync_option(product, sync_optn, inv_wh)
              	
                availabel_inv = inv_wh.available_inv rescue 0
          	    availabel_inv = 0 if availabel_inv.to_i < 0
          	    filters_or_data = { :stockItem => {:qty => availabel_inv.to_s}}
          	    resp = @client.update_product_inv(sync_optn, filters_or_data)
              end
          end
        end
      end
    end
  end
end
