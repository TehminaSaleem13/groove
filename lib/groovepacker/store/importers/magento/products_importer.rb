module Groovepacker
  module Store
    module Importers
      module Magento
        class ProductsImporter < Groovepacker::Store::Importers::Importer
          def import
            handler = self.get_handler
            credential = handler[:credential]
            client = handler[:store_handle][:handle]
            session = handler[:store_handle][:session]
            begin
              response = client.call(:catalog_product_list, message: {session: session})
              result = self.build_result

              #fetching all products
              if response.success?
                #listing found products
                @products = response.body[:catalog_product_list_response][:store_view][:item]
                @products.each do |product|
                  result[:total_imported] = result[:total_imported] + 1

                  if Product.where(:store_product_id => product[:product_id]).length  == 0
                    result_product_id = 
                      self.import_single({sku: product[:sku], product_id: product[:product_id]})
                    result[:success_imported] = result[:success_imported] + 1 unless 
                      result_product_id == 0
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
          def import_single(hash)
            handler = self.get_handler
            credential = handler[:credential]
            client = handler[:store_handle][:handle]
            session = handler[:store_handle][:session]
            sku = hash[:sku]
            product_id = hash[:product_id]
            result_product_id = 0

            begin
            response = client.call(:catalog_product_info, 
              message: {session: session, productId: product_id})

            if response.success?
                @product  = response.body[:catalog_product_info_response][:info]
              #add product to the database
              @productdb = Product.new
              @productdb.name = @product[:name]
              @productdb.store_product_id = @product[:product_id]
              @productdb.product_type = @product[:type]
              @productdb.store = credential.store
              @productdb.weight = @product[:weight].to_f * 16 unless 
                @product[:weight].nil?

              # Magento product api does not provide a barcode, so all
              # magento products should be marked with a status new as t
              #they cannot be scanned.
              @productdb.status = 'new'

              @productdbsku = ProductSku.new
              #add productdb sku
              if @product[:sku] != {:"@xsi:type"=>"xsd:string"}
                @productdbsku.sku = @product[:sku]
                @productdbsku.purpose = 'primary'

                #publish the sku to the product record
                @productdb.product_skus << @productdbsku
              end

              #get images and categories
              if !@product[:sku].nil? && credential.import_images
                getimages = client.call(:catalog_product_attribute_media_list, message: {session: session,
                  productId: product_id})
                if getimages.success?
                  @images = getimages.body[:catalog_product_attribute_media_list_response][:result][:item]
                  if !@images.nil?
                    if @images.kind_of?(Array)
                      @images.each do |image|
                        @productimage = ProductImage.new
                        @productimage.image = image[:url]
                        @productimage.caption = image[:label]
                        @productdb.product_images << @productimage
                      end
                    else
                      @productimage = ProductImage.new
                      @productimage.image = @images[:url]
                      @productimage.caption = @images[:label]
                      @productdb.product_images << @productimage
                    end
                  end
                end
              end

              if credential.import_images && 
                !@product[:categories][:item].nil? &&
                @product[:categories][:item].kind_of?(Array)
                  @product[:categories][:item].each do|category_id|
                    begin
                    get_categories = client.call(:catalog_product_info, message: {session: session,
                      categoryId: category_id})
                      if get_categories.success?
                        @category = get_categories.body[:catalog_product_info_response][:info]
                        @product_cat = ProductCat.new
                        @product_cat.category = @category[:name]

                        if !@product_cat.category.nil?
                          @productdb.product_cats << @product_cat
                        end
                      end
                    rescue
                    end
                  end
              end

              #add inventory warehouse
              puts credential.store.inventory_warehouse_id.to_s
              unless credential.store.nil? && credential.store.inventory_warehouse_id.nil?
                inv_wh = ProductInventoryWarehouses.new
                inv_wh.inventory_warehouse_id = credential.store.inventory_warehouse_id
                @productdb.product_inventory_warehousess << inv_wh
              end

              @productdb.save
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
