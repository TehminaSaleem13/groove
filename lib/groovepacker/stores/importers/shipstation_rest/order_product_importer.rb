module Groovepacker
  module Stores
    module Importers
      module ShipstationRest
        class OrderProductImporter < Groovepacker::Stores::Importers::Importer
          include ProductsHelper
          include Groovepacker::Stores::Importers::ImporterCommonMethods
          
          def find_or_create_product(item)
            init_common_objects
            product = find_create_product(item) #defined in common module which is included in this importer
            return product.try(:id)
          end

          private

          # def get_product_with_temp_skus_item(item)
          #   product_is_nil = Product.find_by_name(item["name"]).nil?
          #   # if sku is nil or empty
          #   if product_is_nil
          #     # and if product is not found by name then create the product
          #     product = create_new_product(item, ProductSku.get_temp_sku)
          #   else
          #     # product exists add temp sku if it does not exist
          #     product = add_sku_for_existing_product(item)
          #   end
          #   return product
          # end

          # def add_sku_for_existing_product(item)
          #   products = Product.where(name: item["name"])
          #   unless contains_temp_skus(products)
          #     product = create_new_product(item, ProductSku.get_temp_sku)
          #   else
          #     product = get_product_with_temp_skus(products)
          #   end
          #   return product
          # end

          def create_new_product(item, sku)
            #create and import product
            product = Product.new(name: item["name"], store: @credential.store, store_product_id: 0)
            product.product_skus.build(sku: sku)

            if @credential.gen_barcode_from_sku && ProductBarcode.where(barcode: sku).empty?
              product.product_barcodes.build(barcode: sku)
            end

            #Build Image
            unless item["imageUrl"].nil? || product.product_images.length > 0
              product.product_images.build(image: item["imageUrl"])
            end
            product.save
            unless item["warehouseLocation"].nil?
              product.primary_warehouse.update_column( 'location_primary', item["warehouseLocation"] )
            end

            product.set_product_status

            product
          end
        end
      end
    end
  end
end
