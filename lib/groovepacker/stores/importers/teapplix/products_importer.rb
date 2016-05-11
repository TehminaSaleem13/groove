module Groovepacker
  module Stores
    module Importers
      module Teapplix
        class ProductsImporter < Groovepacker::Stores::Importers::Importer
          include ProductsHelper

          def import
            initialize_objects
            @bulk_import = true
            @result = self.build_result
            response = @client.products
            
            import_products_count = response["products"].nil? ? 0 : response["products"].length
            send_products_import_email(import_products_count) if import_products_count>20000
            iterate_products_array(response)
            send_products_import_complete_email(import_products_count)
            @result
          end

          def import_teapplix_single_product(teapplix_product)
            initialize_objects
            @bulk_import = false
            teapplix_product["item_title"] = teapplix_product.delete("item_name")
            teapplix_product["sku"] = teapplix_product.delete("item_sku")
            product = create_single_product(teapplix_product)
            return product
          end

          private
            def iterate_products_array(response)
              response["products"].each do |teapplix_product|
                teapplix_product = get_reformatted_json(teapplix_product)
                @result[:total_imported] = @result[:total_imported] + 1
                teapplix_product[:item_title] = teapplix_product[:sku] if teapplix_product[:item_title].blank?
                teapplix_product = teapplix_product.stringify_keys
                create_single_product(teapplix_product) rescue nil
              end
            end

            def initialize_objects
              handler = self.get_handler
              @credential = handler[:credential]
              @store = @credential.store
              @client = handler[:store_handle]
              #@inv_pull_context = init_inv_pull
            end

            def create_single_product(teapplix_product)
              if teapplix_product["sku"].blank?
                # if sku is nil or empty
                product = create_product_with_temp_sku(teapplix_product)
              elsif @bulk_import || (ProductSku.where(sku: teapplix_product["sku"]).length == 0)
                # if non-nil sku is not found
                product = create_new_product(teapplix_product, teapplix_product["sku"])
              else
                product = ProductSku.where(sku: teapplix_product["sku"]).first.product
              end
              return product
            end

            def create_product_with_temp_sku(teapplix_product)
              products = Product.where(name: teapplix_product["item_title"]) rescue []
              # if sku is nil or empty, create new product
              # else if product exists, add temp sku
              product = products.blank? ? create_new_product(teapplix_product, ProductSku.get_temp_sku) : 
                                          add_sku_for_existing_product(teapplix_product, products)
              return product
            end

            def add_sku_for_existing_product(teapplix_product, products)
              product contains_temp_skus(products) ? get_product_with_temp_skus(products) : 
                                                    create_new_product(teapplix_product, ProductSku.get_temp_sku)
              return product
            end

            def create_new_product(teapplix_product, sku)
              product = find_or_init_new_product(teapplix_product)
              product.product_skus.create(sku: sku)
              return product if teapplix_product["sku"].blank?
              
              create_barcode_for_product(product, teapplix_product)
              get_product_categories(product, teapplix_product)
              import_pimary_image(product, teapplix_product)
              make_product_intangible(product)
              create_sync_option_for_product(product, teapplix_product, sku)
              #product.update_product_status
              product.set_product_status
              @result = self.build_result unless @result
              @result[:success_imported] = @result[:success_imported] + 1
              product
            end

            def find_or_init_new_product(teapplix_product)
              product = nil
              if teapplix_product["sku"].present?
                product = ProductSku.find_by_sku(teapplix_product["sku"]).try(:product)
              elsif teapplix_product["item_title"].present?
                product = Product.find_by_name(teapplix_product["item_title"])
              end
              
              if product.blank?
                product = Product.create(name: teapplix_product["item_title"], store: @store)
              end
              return  product
            end

            def create_barcode_for_product(product, teapplix_product)
              if @credential.gen_barcode_from_sku && ProductBarcode.where(barcode: teapplix_product["sku"]).empty?
                product.product_barcodes.create(barcode: teapplix_product["sku"])
              else
                barcode = teapplix_product["upc"].blank? ? nil : teapplix_product["upc"]
                product.product_barcodes.create(barcode: barcode)
              end
            end

            def get_product_categories(product, teapplix_product)
              return if teapplix_product["category"].blank?
              product_cats = product.product_cats
              product_cats.destroy_all
              product_cats.create(category: teapplix_product["category"])
            end

            def import_pimary_image(product, teapplix_product)
              if product.product_images.empty? && !teapplix_product["image_small"].blank?
                product.product_images.create(image: teapplix_product["image_small"])
              end
            end

            def create_sync_option_for_product(product, teapplix_product, sku)
              return unless product.sync_option.nil?
              product.create_sync_option(:teapplix_product_sku => sku, :sync_with_teapplix => true)
              product.save
            end

            def send_products_import_email(products_count)
              ImportMailer.send_products_import_email(products_count, @credential).deliver rescue nil
            end

            def send_products_import_complete_email(products_count)
              ImportMailer.send_products_import_complete_email(products_count, @result, @credential).deliver rescue nil
            end

            def get_reformatted_json(teapplix_product)
              tpx_product = {}
              tpx_product[:item_title] = teapplix_product[:item_title] || teapplix_product["Item Title"]
              tpx_product[:sku] = teapplix_product[:sku] || teapplix_product["SKU"]
              tpx_product[:upc] = teapplix_product[:upc] || teapplix_product["UPC"]
              tpx_product[:category] = teapplix_product[:category] || teapplix_product["Category"]
              tpx_product[:image_small] = teapplix_product[:image_small] || teapplix_product["Image Small"]
              return tpx_product
            end
        end
      end
    end
  end
end
