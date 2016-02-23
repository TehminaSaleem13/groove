module Groovepacker
  module Stores
    module Importers
      module MagentoRest
      	module V2
      	  class Inventory < Groovepacker::Stores::Importers::Importer
      	    include ProductsHelper

            def pull_inventories
              @credential = handler[:credential]
              @client = handler[:store_handle][:handle]

              #products = Product.where(store_id: credential.store_id)
              products = Product.joins(:sync_option).where("sync_with_mg_rest=true and (mg_rest_product_id IS NOT NULL or store_product_id IS NOT NULL)")

              products.each do |product|
              	inv_wh = product.product_inventory_warehousess.first
              	@sync_optn = product.sync_option
              	mg_rest_product_sku = @sync_optn.mg_rest_product_sku
              	next if mg_rest_product_sku.blank?
              	product_stock = @client.stock_item(mg_rest_product_sku)
              	unless product_stock["product_id"].blank?
              	  update_product_inv_for_sync_option(product, product_stock, inv_wh)
              	end
              end
            end

            private
              def update_product_inv_for_sync_option(product, product_stock, inv_wh)
                if @sync_optn.mg_rest_product_id==product_stock["product_id"].to_i
                  inv_wh.quantity_on_hand = product_stock["qty"].to_i rescue 0
                  inv_wh.save!
                end
              end
          end
        end
      end
    end
  end
end
