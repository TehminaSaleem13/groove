module Groovepacker
  module Stores
    module Importers
      module Shippo
        class ProductsImporter < Groovepacker::Stores::Importers::Importer
          include ProductsHelper
          include ProductMethodsHelper

          def import_single_product(item)
            initialize_import_objects
            product = Product.create(
                            name: item['title'],
                            store_product_id: item['object_id'],
                            weight: item['weight'].to_f,
                            store_id: @store.id
                            )
            product.product_skus.create(sku: (item['sku'].present? ? item['sku'] : ProductSku.get_temp_sku), product_id: product.id)
            product.generate_numeric_barcode({}) if @credential.generate_barcode_option == 'generate_numeric_barcode'
            product.generate_barcode({}) if @credential.generate_barcode_option == 'generate_from_sku'
            product.set_product_status
            product
          end

          private

          def initialize_import_objects
            handler = get_handler
            @credential = handler[:credential]
            @store = @credential.try(:store)
          end
          
        end
      end
    end
  end
end