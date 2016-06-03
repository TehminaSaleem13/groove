module Groovepacker
  module Stores
    module Importers
      module BigCommerce
        class ProductsImporter < Groovepacker::Stores::Importers::Importer
          include ProductsHelper
          include Groovepacker::Stores::Importers::ImporterCommonMethods

          def import
            initialize_objects
            @result = self.build_result
            response = @client.products
            
            import_products_count = response["products"].nil? ? 0 : response["products"].length
            send_products_import_email(import_products_count) if import_products_count>20000
            iterate_product_response_array(response)
            send_products_import_complete_email(import_products_count)
            @result
          end

          def import_bc_single_product(bc_product, import_inv = true)
            initialize_objects
            product = create_single_product(bc_product, import_inv)
            return product
          end

          private
            def iterate_product_response_array(response)
              response["products"].each do |bc_product|
                skus = @client.product_skus(bc_product["skus"]["url"])
                if skus
                  create_single_product_from_product_sku(bc_product, skus) rescue nil
                  next
                end
                @result[:total_imported] = @result[:total_imported] + 1
                create_single_product(bc_product) rescue nil
              end
            end

            def create_single_product_from_product_sku(bc_product, skus)
              skus.each do |bc_sku_product|
                @result[:total_imported] = @result[:total_imported] + 1
                bc_sku_product = update_product_attrs_for_product_sku(bc_product, bc_sku_product)
                create_single_product(bc_sku_product)
              end
            end

            def update_product_attrs_for_product_sku(bc_product, bc_sku_product)
              bc_sku_product.delete("weight") if bc_sku_product["weight"].blank?
              bc_sku_product.each {|key, val| bc_product[key] = val}
              bc_product["primary_image"]["standard_url"] = bc_sku_product["image_file"] unless bc_sku_product["image_file"].blank?
              bc_product
            end

            def initialize_objects
              handler = self.get_handler
              @credential = handler[:credential]
              @store = @credential.store
              @client = handler[:store_handle]
              @inv_pull_context = init_inv_pull
            end

            def create_single_product(bc_product, import_inv=true)
              product = find_create_product(bc_product) #defined in common module which is included in this importer
              @inv_pull_context.pull_single_product_inventory(product) if import_inv
              return product
            end

            def create_new_product(bc_product, sku)
              #create and import product
              product = Product.create(name: bc_product["name"], store: @store,
                                       store_product_id: bc_product["id"],
                                       weight: bc_product["weight"])
              product.product_skus.create(sku: sku)

              #get from products api
              #we are fetching product again here because the order_item may also
              #be passed as bc_product in this method.
              bc_product = @client.product(bc_product["product_id"]) if bc_product["order_id"].present?

              unless bc_product.nil?
                barcode = bc_product["upc"].blank? ? nil : bc_product["upc"]
                product.product_barcodes.create(barcode: barcode)
                
                # get product categories
                get_product_categories(product, bc_product)
                
                #Product skus are variants in BigCommerce
                #create_barcodes_and_images_from_variants(product, bc_product, sku)
                
                # if product images are empty then import product image
                import_pimary_image(product, bc_product)
              end

              create_sync_option_for_product(product, bc_product, sku)
              
              make_product_intangible(product)
              #product.update_product_status
              product.set_product_status
              @result = self.build_result unless @result
              @result[:success_imported] = @result[:success_imported] + 1
              product
            end

            def get_product_categories(product, bc_product)
              return if bc_product["categories"].blank?
              tags = []
              product_categories.select {|cat| tags << cat["name"] if bc_product["categories"].include?(cat["id"])}
              tags.each do |tag|
                product.product_cats.create(category: tag)
              end
            end

            def product_categories
              @categories ||= @client.product_categories("https://api.bigcommerce.com/#{@client.as_json["store_hash"]}/v2/categories")
            end

            def create_barcodes_and_images_from_variants(product, bc_product, sku)
              return if bc_product["skus"].blank? 
              product_skus = @client.product_skus(bc_product["skus"]["url"]) || []
              product_skus.each do |variant|
                next unless variant["sku"] == sku
                # create barcode
                barcode = variant["upc"].blank? ? nil : variant["upc"]
                product.product_barcodes.create(barcode: barcode)
                # get image based on the variant id
                get_variant_images_for_product(product, bc_product)
              end
            end

            def import_pimary_image(product, bc_product)
              if product.product_images.empty? && !bc_product["primary_image"].blank?
                product.product_images.create(image: bc_product["primary_image"]["standard_url"])
              end
            end

            def create_sync_option_for_product(product, bc_product, sku)
              return unless product.sync_option.nil?
              product.create_sync_option(:bc_product_id => bc_product["id"], :bc_product_sku => sku, :sync_with_bc => true)
              product.save
            end

            def get_variant_images_for_product(product, bc_product)
              images = @client.product_images(bc_product["images"]["url"])
              (images||[]).each do |image|
                product.product_images.create(image: image["src"])
              end
            end

            def init_inv_pull
              handler = Groovepacker::Stores::Handlers::BigCommerceHandler.new(@store)
              context = Groovepacker::Stores::Context.new(handler)
              return context
            end

            def send_products_import_email(products_count)
              ImportMailer.send_products_import_email(products_count, @credential).deliver rescue nil
            end

            def send_products_import_complete_email(products_count)
              ImportMailer.send_products_import_complete_email(products_count, @result, @credential).deliver rescue nil
            end
        end
      end
    end
  end
end
