module Groovepacker
  module Stores
    module Importers
      module Teapplix
        class Inventory < Groovepacker::Stores::Importers::Importer
          include ProductsHelper

          def pull_inventories
            init_credential_and_client(handler)

            #products = Product.where(store_id: credential.store_id)
            products = Product.joins(:sync_option).where("sync_with_teapplix=true and (teapplix_product_sku IS NOT NULL)")
            @response = @client.fetch_inventory_for_products
            (products||[]).each do |product|
              begin
                inv_wh = product.product_inventory_warehousess.first
                @sync_optn = product.sync_option
                teapplix_product_sku = @sync_optn.teapplix_product_sku
                teapplix_product = get_inv_product(teapplix_product_sku).first || {}
                unless teapplix_product["SKU"].blank?
                  update_product_inv_for_sync_option(product, teapplix_product, inv_wh)
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

            def get_inv_product(sku)
              inv_product = @response["inventories"].select {|inv| inv["SKU"]==sku}
            end

            def update_product_inv_for_sync_option(product, teapplix_product, inv_wh)
              if @sync_optn.teapplix_product_sku==teapplix_product["SKU"]
                inv_wh.quantity_on_hand = teapplix_product["Qty Available"].try(:to_i) + inv_wh.allocated_inv.to_i
                inv_wh.save!
              end
            end
        end
      end
    end
  end
end
