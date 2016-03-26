module Groovepacker
  module Stores
    module Importers
      module Shopify
        class ProductsImporter < Groovepacker::Stores::Importers::Importer
          include ProductsHelper

          def import
            initialize_import_objects
            response = @client.products
            return @result if response["products"].blank?
            response["products"].each do |product|
              product = create_single_product(product)
            end
            
            result
          end

          # def import_single_product(item)
          #   handler = self.get_handler
          #   credential = handler[:credential]
          #   client = handler[:store_handle]
          #   product = create_single_product(item, client, credential)
          #   return product
          # end

          private
            
            def initialize_import_objects
              handler = self.get_handler
              @credential = handler[:credential]
              @store = @credential.store
              @client = handler[:store_handle]
              #@import_item = handler[:import_item]
              @result = self.build_result
            end

            def create_single_product(shopify_product)
              shopify_product["variants"].each do |variant|
                variant["title"] = "#{shopify_product["title"]} - #{variant["title"]}"
                create_product_from_variant(variant, shopify_product)    
              end
            end
            
            def create_product_from_variant(variant, shopify_product)
              if variant["sku"].blank?
                create_product_with_temp_sku(variant, shopify_product)
              elsif ProductSku.where(sku: variant["sku"]).length == 0
                # if non-nil sku is not found
                create_new_product_from_order(variant, variant["sku"], shopify_product)
              end
            end

            def create_product_with_temp_sku(variant, shopify_product)
              # if sku is nil or empty
              products = Product.where(name: variant["title"])
              if products.blank?
                # if item is not found by name then create the variant
                create_new_product_from_order(variant, ProductSku.get_temp_sku, shopify_product)
              else
                # product exists add temp sku if it does not exist
                unless contains_temp_skus(products)
                  create_new_product_from_order(variant, ProductSku.get_temp_sku, shopify_product)
                end
              end
            end

            def create_new_product_from_order(variant, sku, shopify_product)
              #create and import product
              product = Product.create(name: variant["title"], store: @store,
                                       store_product_id: variant["product_id"])
              
              product.product_skus.create(sku: sku)
              # get product categories
              add_tags(product, shopify_product)
              # create barcode
              product.product_barcodes.create(barcode: variant["barcode"])
              # get image based on the variant id
              add_image(variant, product, shopify_product)
              #update inventory level
              update_inventory(product, variant)
              # get weight
              assign_weight(product, variant)
              product.reload
              create_sync_option_for_product(product, variant)
              make_product_intangible(product)
              product.update_product_status
            end

            def create_sync_option_for_product(product, variant)
              product_sync_option = product.sync_option
              if product_sync_option.nil?
                product.create_sync_option(:shopify_product_variant_id => variant["id"], :sync_with_shopify => true)
              else
                product_sync_option.update_attributes(:shopify_product_variant_id => variant["id"], :sync_with_shopify => true)
              end
            end

            def assign_weight(product, variant)
              weight_in = { 'lb' => variant["weight"]*16, 
                            'kg' => variant["weight"]*35.274,
                            'g' =>  variant["weight"]*0.035274,
                            'oz' => variant["weight"]
                          }
              product.weight=weight_in['lb']
              product.save
            end

            def add_tags(product, shopify_product)
              return if shopify_product["tags"].blank?
              tags = shopify_product["tags"].split(", ")
              tags.each { |tag| product.product_cats.create(category: tag) }
            end

            def add_image(variant, product, shopify_product)
              variant_image = shopify_product["images"].select {|image| image["id"]==variant["image_id"]}.first
              variant_image = variant_image || shopify_product["image"]
              variant_image_src = variant_image["src"] rescue nil
              product.product_images.create(image: variant_image_src)
            end

            def update_inventory(product, variant)
              inv_wh = product.product_inventory_warehousess.first
              inv_wh = product.product_inventory_warehousess.new if inv_wh.blank?
              inv_wh.quantity_on_hand = variant["inventory_quantity"].try(:to_i) + inv_wh.allocated_inv.to_i
              inv_wh.save
            end

        end
      end
    end
  end
end
