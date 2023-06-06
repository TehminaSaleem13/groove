# frozen_string_literal: true

module Groovepacker
  module Stores
    module Importers
      module ImporterCommonMethods
        def find_create_product(r_product)
          product = if r_product['sku'].blank?
                      # if sku is nil or empty
                      create_product_with_temp_sku(r_product)
                    elsif ProductSku.where(sku: r_product['sku']).empty?
                      # if non-nil sku is not found
                      create_new_product(r_product, r_product['sku'], r_product["adjustment"])
                    else
                      ProductSku.where(sku: r_product['sku']).first.product
                    end
          product.reload
          if ( @credential.set_coupons_to_intangible || check_for_intangible_coupon )
            r_product["adjustment"] ? make_coupon_intangible(product.id) : make_product_intangible(product)
          end
          product.set_product_status
          product
        end

        def create_product_with_temp_sku(r_product)
          product_is_nil = Product.find_by_name(r_product['name']).nil?
          # if sku is nil or empty
          product = if product_is_nil
                      # and if product is not found by name then create the product
                      create_new_product(r_product, ProductSku.get_temp_sku, r_product["adjustment"]) # this method is defined in respective importer
                    else
                      # product exists add temp sku if it does not exist
                      add_sku_for_existing_product(r_product)
                    end
          product
        end

        def add_sku_for_existing_product(r_product)
          products = Product.where(name: r_product['name'])
          product = if contains_temp_skus(products)
                      get_product_with_temp_skus(products)
                    else
                      create_new_product(r_product, ProductSku.get_temp_sku, r_product["adjustment"]) # this method is defined in respective importer
                        end
          product
        end

        def create_new_product(item, sku, is_coupon)
          # create and import product
          if check_for_replace_product
            coupon_product = is_coupon ? replace_coupon(item['name'], sku) : replace_product(item['name'], sku)
            return coupon_product unless coupon_product.nil?
          end
          product = Product.create(name: item['name'], store: @credential.store, store_product_id: item['productId'])
          product.add_product_activity('Product Import', @credential.store.name.to_s)
          product.product_skus.create(sku: sku)
          if @credential.gen_barcode_from_sku && @credential.import_upc && item['upc'].present? && item['upc'] != '0'
            product.product_barcodes.create(barcode: item['upc'])
          elsif @credential.gen_barcode_from_sku && ProductBarcode.where(barcode: sku).empty?
            product.product_barcodes.create(barcode: sku)
          end

          # Build Image
          unless item['imageUrl'].nil? || !product.product_images.empty?
            product.product_images.create(image: item['imageUrl'])
          end
          begin
              product.reload
          rescue StandardError
            nil
            end
          # product.save
          unless item['warehouseLocation'].nil?
            product.primary_warehouse.update_column('location_primary', item['warehouseLocation'])
          end
          product
        end
      end
    end
  end
end
