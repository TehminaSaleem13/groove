module Groovepacker
  module Stores
    module Importers
      module ShippingEasy
        module ProductsImporter
          include ProductsHelper

          def find_or_create_order_item_product(item, store)
            if item["sku"].blank?
              # if sku is nil or empty
              if Product.find_by_name(item["item_name"]).nil?
                # if item is not found by name then create the item
                order_item_product = create_new_product_from_order(item, store, ProductSku.get_temp_sku)
              else
                # product exists add temp sku if it does not exist
                products = Product.where(name: item["item_name"])
                unless contains_temp_skus(products)
                  order_item_product = create_new_product_from_order(item, store, ProductSku.get_temp_sku)
                else
                  #get_product_with_temp_skus is defined in Importer class which is derived in Orders Importer
                  order_item_product = get_product_with_temp_skus(products)
                end
              end
            elsif ProductSku.where(sku: item["sku"]).length == 0
              # if non-nil sku is not found
              order_item_product = create_new_product_from_order(item, store, item["sku"])
            else
              order_item_product = ProductSku.where(sku: item["sku"]).first.product
            end
            order_item_product
          end

          def create_new_product_from_order(item, store, sku)
            product = Product.create(name: item["item_name"], store: store,
                                     store_product_id: item["ext_line_item_id"],
                                     weight: item["weight_in_ounces"])
            
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
