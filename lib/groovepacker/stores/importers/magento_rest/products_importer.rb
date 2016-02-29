module Groovepacker
  module Stores
    module Importers
      module MagentoRest
        class ProductsImporter < Groovepacker::Stores::Importers::Importer
          include ProductsHelper

          def import
            binding.pry
            result = get_importer.import
          end

          def import_single(product_attrs={})
            result = get_importer.import_single(product_attrs)
          end

          private
            def get_importer
              handler = self.get_handler
              credential = handler[:credential]
              if credential.store_version=='2.x'
                importer = Groovepacker::Stores::Importers::MagentoRest::V2::ProductsImporter.new(handler)
              else
                importer = Groovepacker::Stores::Importers::MagentoRest::V1::ProductsImporter.new(handler)
              end
              return importer
            end
        end
      end
    end
  end
end
