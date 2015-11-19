module Groovepacker
  module Stores
    module Importers
      module MagentoRest
        class ProductsImporter < Groovepacker::Stores::Importers::Importer
          include ProductsHelper

          def import
            handler = self.get_handler
            credential = handler[:credential]
            client = handler[:store_handle][:handle]
            begin
              response = client.products
              result = self.build_result
              #fetching all products
              unless response.blank?
                #listing found products
                @products = response
                @products.each do |product|
                  product = product.last
                  result[:total_imported] = result[:total_imported] + 1

                  if Product.where(:store_product_id => product["entity_id"]).length == 0
                    result_product_id = self.import_single(product)
                    result[:success_imported] = result[:success_imported] + 1 unless result_product_id == 0
                  else
                    result[:previous_imported] = result[:previous_imported] + 1
                  end
                end
              else
                result[:status] &= false
                result[:messages].push('Problem retrieving products list')
              end
            rescue Exception => e
              result[:status] &= false
              result[:messages].push(e)
            end
            result
          end

          #sku
          def import_single(product_attrs={})
            handler = self.get_handler
            credential = handler[:credential]
            client = handler[:store_handle][:handle]
            # session = handler[:store_handle][:session]
            # sku = hash[:sku]
            # product_id = hash[:product_id]
            result_product_id = 0

            begin

              unless product_attrs.blank?
                #add product to the database
                @productdb = Product.new
                @productdb.name = product_attrs["name"]
                @productdb.store_product_id = product_attrs["entity_id"]
                @productdb.product_type = product_attrs["type_id"]
                @productdb.store = credential.store
                @productdb.weight = product_attrs["weight"].to_f * 16 unless product_attrs["weight"].nil?

                # Magento product api does not provide a barcode, so all
                # magento products should be marked with a status new as t
                #they cannot be scanned.
                @productdb.status = 'new'

                @productdbsku = ProductSku.new
                #add productdb sku
                if product_attrs["sku"] != {:"@xsi:type" => "xsd:string"}
                  @productdbsku.sku = product_attrs["sku"]
                  @productdbsku.purpose = 'primary'

                  #publish the sku to the product record
                  @productdb.product_skus << @productdbsku
                end

                if !product_attrs["sku"].nil? && credential.import_images
                  product_images = client.product_images(product_attrs["entity_id"])
                  unless product_images.blank?
                    (product_images||[]).each do |image|
                      @productimage = ProductImage.new
                      @productimage.image = image["url"]
                      @productimage.caption = image["label"]
                      @productdb.product_images << @productimage
                    end
                  end
                end

                #add inventory warehouse
                unless credential.store.nil? && credential.store.inventory_warehouse_id.nil?
                  inv_wh = ProductInventoryWarehouses.new
                  inv_wh.inventory_warehouse_id = credential.store.inventory_warehouse_id
                  @productdb.product_inventory_warehousess << inv_wh
                end

                @productdb.save
                make_product_intangible(@productdb)
                @productdb.set_product_status
                result_product_id = @productdb.id
              end
            rescue Exception => e
              Rails.logger.info(e)
            end
            result_product_id
          end
        end
      end
    end
  end
end
