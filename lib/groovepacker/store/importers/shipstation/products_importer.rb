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
            products = client.product.all
            puts "successfully entered to import products."
            if !products.nil?
              result[:total_imported] = products.length
              products.each do |item|
                if ProductSku.where(:sku=>item.SKU).length == 0
                  @product = Product.new
                  set_product_fields(@product,item)
                end
              end
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
            # product.store_product_id = 
            product.name = ssproduct.Name
            # product_type = 
            # product.store_id = 
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
            product.weight = ssproduct.WeightOz
            # product.shipping_weight = 
            # product.is_packing_supply =
            product.save
            product.update_product_status
          end
        end
      end
    end
  end
end