module Groovepacker
  module Stores
    module Importers
      module MagentoRest
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
              mg_rest_product_id = (@sync_optn.mg_rest_product_id rescue nil) || product.mg_rest_product_id
              mg_rest_product = @client.product(mg_rest_product_id)
              unless mg_rest_product["entity_id"].blank?
                update_product_inv_for_sync_option(product, mg_rest_product, inv_wh)
              end
            end
          end

          private
            def update_product_inv_for_sync_option(product, mg_rest_product, inv_wh)
              if @sync_optn.mg_rest_product_id==mg_rest_product["entity_id"].to_i
                inv_wh.quantity_on_hand = mg_rest_product["stock_data"]["qty"].to_i
                inv_wh.save!
              end
            end
        end
      end
    end
  end
end
