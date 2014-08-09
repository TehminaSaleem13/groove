module Groovepacker
  module Store
    module Importers
      module Shipstation
        class ProductsImporter < Groovepacker::Store::Importers::Importer
          def import
            handler = self.get_handler
            credential = handler[:credential]
            client = handler[:store_handle]
            puts "client:" + client.inspect
            result = self.build_result
            puts "credential: " + credential.inspect
            products = client.product.all
            puts "successfully entered to import products."
            if !products.nil?
              result[:total_imported] = products.length.to_s
              puts "total_imported:" + products.length.to_s
              products.each do |item|
                if ProductSku.where(:sku=>item.SKU).length == 0
                  @product = Product.new
                  @product.store_id = credential.store_id
                  @product.store_product_id = 0
                  sku = ProductSku.new
                  sku.sku = item.SKU
                  @product.product_skus << sku

                  if set_product_fields(@product,item)
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
              puts "start importing the product."
              credential = import_hash[:handler][:credential]
              client = import_hash[:handler][:store_handle]
              sku = import_hash[:product_sku] 
              id = import_hash[:product_id]
              products = client.product.where("SKU"=>sku)
              if !products.nil?
                product = products.first
                @product = Product.find(id)
                set_product_fields(@product,product)
              end 
            rescue Exception => e
              result &= false
              Rails.logger.info('Error updating the product sku ' + e.to_s)
            end
            result
          end
          def set_product_fields(product, ssproduct)
            result = false
            # product.store_product_id = 
            product.name = ssproduct.Name
            # product_type = 
            # product.store_id = ssproduct.store.id
            product.inv_wh1 = ssproduct.WarehouseLocation
            # product.status =
            # product.spl_instructions_4_packer = 
            # product.spl_instructions_4_confirmation = 
            # product.alternate_location = 
            # product.barcode = 
            # product.is_skippable = 
            # product.packing_placement = 
            # product.pack_time_adj = 
            # product.kit_parsing = 
            # product.is_kit = 
            # product.disable_conf_req = 
            # product.total_avail_ext = 
            if !ssproduct.WeightOz.nil?
              product.weight = ssproduct.WeightOz
            else
              product.weight = 0
            end
            # product.shipping_weight = 
            # product.is_packing_supply =
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