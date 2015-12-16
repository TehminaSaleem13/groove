module Groovepacker
  module Stores
    module Importers
      module BigCommerce
        class ProductsImporter < Groovepacker::Stores::Importers::Importer
          include ProductsHelper

          def import
            initialize_objects
            result = self.build_result
            response = @client.products
            
            result[:total_imported] = response["products"].nil? ? 0 : response["products"].length

            response["products"].each do |bc_product|
              create_single_product(bc_product)
            end
            
            result
          end

          def import_bc_single_product(bc_product, import_inv = true)
            initialize_objects
            product = create_single_product(bc_product, import_inv)
            return product
          end

          private
            def initialize_objects
              handler = self.get_handler
              @credential = handler[:credential]
              @store = @credential.store
              @client = handler[:store_handle]
              @inv_pull_context = init_inv_pull
            end

            def create_single_product(bc_product, import_inv=true)
              if bc_product["sku"].blank?
                # if sku is nil or empty
                create_product_with_temp_sku(bc_product)
              elsif ProductSku.where(sku: bc_product["sku"]).length == 0
                # if non-nil sku is not found
                product = create_new_product(bc_product, bc_product["sku"])
              else
                product = ProductSku.where(sku: bc_product["sku"]).first.product
              end
              @inv_pull_context.pull_single_product_inventory(product) if import_inv
              return product
            end

            def create_product_with_temp_sku(bc_product)
              product_is_nil = Product.find_by_name(bc_product["name"]).nil?
              # if sku is nil or empty
              if product_is_nil
                # and if product is not found by name then create the product
                product = create_new_product(bc_product, ProductSku.get_temp_sku)
              else
                # product exists add temp sku if it does not exist
                product = add_sku_for_existing_product(bc_product)
              end
              return product
            end

            def add_sku_for_existing_product(bc_product)
              products = Product.where(name: bc_product["name"])
              unless contains_temp_skus(products)
                product = create_new_product(bc_product, ProductSku.get_temp_sku)
              else
                product = get_product_with_temp_skus(products)
              end
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
                create_barcodes_and_images_from_variants(product, bc_product, sku)
                
                # if product images are empty then import product image
                import_pimary_image(product, bc_product)
              end

              create_sync_option_for_product(product, bc_product, sku)
              
              make_product_intangible(product)
              #product.update_product_status
              product.set_product_status
              product
            end

            def get_product_categories(product, bc_product)
              return if bc_product["categories"].blank?
              tags = []
              categories = @client.product_categories("https://api.bigcommerce.com/#{@client.as_json["store_hash"]}/v2/categories")
              categories.select {|cat| tags << cat["name"] if bc_product["categories"].include?(cat["id"])}
              tags.each do |tag|
                product.product_cats.create(category: tag)
              end
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
<<<<<<< HEAD
            
=======

>>>>>>> Minor code changes for products importer
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
        end
      end
    end
  end
end
