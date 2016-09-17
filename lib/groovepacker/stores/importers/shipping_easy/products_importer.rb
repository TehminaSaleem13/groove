module Groovepacker
  module Stores
    module Importers
      module ShippingEasy
        module ProductsImporter
          include ProductsHelper

          def find_or_create_order_item_product(item, store)
            product_skus = ProductSku.where(sku: item["sku"])
            order_item_product =  if item["sku"].blank?
                                    find_by_name_or_create(item, store)
                                  elsif product_skus.length==0
                                    # if non-nil sku is not found
                                    create_new_product_from_order(item, store, item["sku"])
                                  else
                                    product_skus.first.product
                                  end
          end

          def find_by_name_or_create(item, store)
            # if sku is nil or empty
            products = Product.where(name: item["item_name"])
            if products.nil?
              # if item is not found by name then create the item
              order_item_product = create_new_product_from_order(item, store, ProductSku.get_temp_sku)
              return order_item_product
            end
            
            # product exists add temp sku if it does not exist
            order_item_product =  unless contains_temp_skus(products)
                                    create_new_product_from_order(item, store, ProductSku.get_temp_sku)
                                  else
                                    #get_product_with_temp_skus is defined in Importer class which is derived in Orders Importer
                                    get_product_with_temp_skus(products)
                                  end
          end

          def create_new_product_from_order(item, store, sku)
            product_weight = item["weight_in_ounces"] || "0.0"
            product = Product.create(name: item["item_name"], store: store,
                                     store_product_id: item["ext_line_item_id"],
                                     weight: product_weight)
            
            product.product_skus.create(sku: sku)

            if @credential.gen_barcode_from_sku && ProductBarcode.where(barcode: sku).empty?
              product.product_barcodes.create(barcode: sku)
            end
            product.set_product_status
            product
          end

        end
      end
    end
  end
end
