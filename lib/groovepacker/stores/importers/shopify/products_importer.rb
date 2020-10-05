module Groovepacker
  module Stores
    module Importers
      module Shopify
        class ProductsImporter < Groovepacker::Stores::Importers::Importer
          include ProductsHelper

          def import(product_import_type, product_import_range_days)
            initialize_import_objects
            begin
              response = @client.products(product_import_type, product_import_range_days)
            rescue
              Product.emit_message_for_access_token
            end
            if response["products"] == [nil]
              Product.emit_message_for_access_token
              return
            end
            return if response["products"].blank?
            products_response = response["products"].compact.sort_by { |products| Time.zone.parse(products['updated_at']) }
            products_response.each do |product|
              create_single_product(product)
              @credential.update_attributes(product_last_import: Time.zone.parse(product['updated_at'])) # if products_response.last == product
            end
            update_orders_status
            send_products_import_complete_email(response["products"].count)
          end

          def import_single_product(item)
            initialize_import_objects
            fetch_product(item)
            if @shopify_product.present?
              variant = @shopify_product["variants"].select {|variant| variant["id"]==item["variant_id"]}.first
              begin
                variant["title"] = item["name"] 
                product = create_product_from_variant(variant, @shopify_product)
              rescue
                product = nil
              end
            end

            return product
          end

          def fetch_product(item)
            shopify_product = @client.product(item["product_id"])
            if shopify_product["product"].blank?
              loop_count = 0
              loop do
                loop_count = loop_count + 1
                shopify_product = @client.product(item["product_id"])
                break if loop_count >= 1
              end
            end
            @shopify_product = shopify_product["product"]
          end

          private
            
            def initialize_import_objects
              handler = self.get_handler
              @credential = handler[:credential]
              @store = @credential.try(:store)
              @client = handler[:store_handle]
            end

            def create_single_product(shopify_product)
              shopify_product["variants"].each do |variant|
                variant_title = variant["title"]=="Default Title" ? "" : " - #{variant["title"]}"
                variant["title"] = shopify_product["title"] + variant_title
                product = create_product_from_variant(variant, shopify_product)   
                product = product.reload rescue product
                product.product_inventory_warehousess.first.update_attributes(available_inv: variant['inventory_quantity']) if @credential.import_inventory_qoh
                product.set_product_status
              end
            end

            def create_product_from_variant(variant, shopify_product)
              if variant["sku"].blank?
                product = create_product_with_temp_sku(variant, shopify_product)
              elsif @credential.import_updated_sku && ProductSku.where(sku: variant["sku"]).length == 0 &&  Product.where(store_product_id: variant["id"]).length != 0
                product = Product.where(store_product_id: variant["id"]).first
                product.product_skus.destroy_all if @credential.updated_sku_handling == 'remove_all'
                product.product_skus.create(sku: variant["sku"])
                update_product_details_barcode(product, variant)
              elsif ProductSku.where(sku: variant["sku"]).length == 0
                # if non-nil sku is not found
                product = create_new_product_from_order(variant, variant["sku"], shopify_product)
              else
                product = ProductSku.where(sku: variant["sku"]).first.product
                update_product_details_barcode(product, variant)
              end
              return product
            end

            def update_product_details_barcode(product, variant)
              product.update_attributes(name: variant['title'])
              add_barcode_to_product(product, variant) if variant['barcode'].present? && product.product_barcodes.where(barcode: variant['barcode']).blank?
            end

            def add_barcode_to_product(product, variant)
              product.product_barcodes.destroy_all if @credential.modified_barcode_handling != 'add_to_existing'
              product.product_barcodes.create(barcode: variant['barcode'])
              product.touch
            end

            def create_product_with_temp_sku(variant, shopify_product)
              # if sku is nil or empty
              products = Product.where(name: variant["title"])
              if products.blank?
                # if product is not found by name then create the variant
                product = create_new_product_from_order(variant, ProductSku.get_temp_sku, shopify_product)
              else
                # product exists add temp sku if it does not exist
                unless contains_temp_skus(products)
                  product = create_new_product_from_order(variant, ProductSku.get_temp_sku, shopify_product)
                else
                  product = get_product_with_temp_skus(products)
                end
              end
              return product
            end

            def create_new_product_from_order(variant, sku, shopify_product)
              #create and import product
              if check_for_replace_product
                coupon_product = replace_product(variant["title"], sku)
                return coupon_product unless coupon_product.nil? 
              end 
              product = Product.create(name: variant["title"], store: @store,
                                       store_product_id: variant["id"])
              
              product.add_product_activity("Product Import","#{product.store.try(:name)}")
              product.product_skus.create(sku: sku)
              # get product categories
              add_tags(product, shopify_product)
              # create barcode
              create_product_barcode(product, variant)
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
              return product
            end

            def create_sync_option_for_product(product, variant)
              product_sync_option = product.sync_option
              if product_sync_option.nil?
                product.create_sync_option(:shopify_product_variant_id => variant["id"], :sync_with_shopify => true)
              else
                product_sync_option.update_attributes(:shopify_product_variant_id => variant["id"], :sync_with_shopify => true)
              end
            end

            def create_product_barcode(product, variant)
              case @credential.generating_barcodes
              when 'generate_from_sku'
                product.product_barcodes.create(barcode: variant['sku']) if variant['sku'].present?
              when 'import_from_shopify'
                barcode = variant['barcode'].present? ? variant['barcode'] : variant['sku']
                product.product_barcodes.create(barcode: barcode) if barcode.present?
              when 'do_not_generate'
                product.product_barcodes.create(barcode: variant['barcode']) if variant['barcode'].present?
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

            def send_products_import_complete_email(products_count)
              result = { status: true, success_imported: products_count }

              ImportMailer.send_products_import_complete_email(products_count, result, @credential).deliver rescue nil
            end
        end
      end
    end
  end
end
