module Groovepacker
  module Store
    module Importers
      module Shipstation
        class ProductsImporter < Groovepacker::Store::Importers::Importer
          def import
            handler = self.get_handler
            credential = handler[:credential]
            client = handler[:store_handle]
            result = self.build_result
            products = client.product.all
            unless products.nil?
              result[:total_imported] = products.length.to_s
              products.each do |item|
                if ProductSku.where(:sku=>item.sku).length == 0
                  @product = Product.new
                  @product.store_id = credential.store_id
                  @product.store_product_id = 0
                  sku = ProductSku.new
                  sku.sku = item.sku
                  @product.product_skus << sku

                  if set_product_fields(@product,item,credential)
                    result[:success_imported] = result[:success_imported] + 1
                  else
                    result[:status] &= false
                    result[:messages] = "The product information could not be saved."
                  end
                else
                  result[:previous_imported] = result[:previous_imported] + 1
                end
              end
            else
              result[:status] &= false
              result[:messages] = "No available products."
            end
            result
          end

          def import_single(import_hash)
            result = true
            begin
              credential = import_hash[:handler][:credential]
              client = import_hash[:handler][:store_handle]
              sku = import_hash[:product_sku] 
              id = import_hash[:product_id]
              products = client.product.where("SKU"=>sku)
              unless products.nil?
                product = products.first
                @product = Product.find(id)
                set_product_fields(@product,product,credential)
              end 
            rescue Exception => e
              result &= false
              Rails.logger.info('Error updating the product sku ' + e.to_s)
            end
            result
          end
          def set_product_fields(product, ssproduct,credential)
            result = false 
            product.name = ssproduct.name

            unless credential.store.nil? or 
              credential.store.inventory_warehouse_id.nil? or 
              product.product_inventory_warehousess.pluck(:inventory_warehouse_id).include?(credential.store.inventory_warehouse_id) then
              inv_wh = ProductInventoryWarehouses.new
              inv_wh.inventory_warehouse_id = credential.store.inventory_warehouse_id
              inv_wh.location_primary = ssproduct.warehouse_location
              product.product_inventory_warehousess << inv_wh
            end
 
            unless ssproduct.weight_oz.nil?
              product.weight = ssproduct.weight_oz
            else
              product.weight = 0
            end

            if product.save
              result = true
            end
            product.update_product_status
            result
          end
        end
      end
    end
  end
end