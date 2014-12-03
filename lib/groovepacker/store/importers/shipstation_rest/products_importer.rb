module Groovepacker
  module Store
    module Importers
      module ShipstationRest
        include ProductsHelper
        class ProductsImporter < Groovepacker::Store::Importers::Importer
          def import
            handler = self.get_handler
            credential = handler[:credential]
            client = handler[:store_handle]
            result = self.build_result
            product_result = client.get_products
            puts product_result.inspect
            unless product_result["products"].nil?
              result[:total_imported] = product_result["products"].length.to_s

              # loop through the products
              product_result["products"].each do |item|
                import_result = false
                previous_import = false
                if item["sku"].nil? or item["sku"] == ''
                  # if sku is empty
                  if Product.find_by_name(item["name"]).nil?
                    # product does not exist create one with temp sku
                    import_result = create_new_product(item, ProductSku.get_temp_sku, credential)
                  else
                    # product exists add temp sku if it does not exist
                    unless contains_temp_skus(Product.where(name: item["name"]))
                      import_result = create_new_product(item, ProductSku.get_temp_sku, credential)
                    else
                      previous_import = true
                    end
                  end
                elsif ProductSku.where(:sku => item["sku"]).length == 0 
                  # valid sku but not found earlier
                  import_result = create_new_product(item, item["sku"], credential)
                else 
                  # sku is already found
                  previous_import = true
                end

                if previous_import
                  result[:previous_imported] = result[:previous_imported] + 1
                elsif import_result
                  result[:success_imported] = result[:success_imported] + 1
                else
                  result[:status] &= false
                  result[:messages] = "The product information could not be saved."
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

          private 

          def create_new_product(item, sku, credential)
            product = Product.create(store: credential.store, store_product_id: 0,
              name: item["name"])
            product.product_skus.create(sku: sku)
            set_product_fields(product, item, credential)
          end

          def set_product_fields(product, ssproduct, credential)
            result = false 
            product.name = ssproduct["name"]

            unless credential.store.nil? or 
              credential.store.inventory_warehouse_id.nil? or 
              product.product_inventory_warehousess.pluck(:inventory_warehouse_id).include?(credential.store.inventory_warehouse_id) then
              inv_wh = ProductInventoryWarehouses.new
              inv_wh.inventory_warehouse_id = credential.store.inventory_warehouse_id
              inv_wh.location_primary = ssproduct["warehouseLocation"]
              product.product_inventory_warehousess << inv_wh
            end
            
            unless ssproduct["productCategory"].nil?
              product.product_cats.create(category: 
                ssproduct["productCategory"]["name"])
            end

            unless ssproduct["weightOz"].nil?
              product.weight = ssproduct["weightOz"]
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