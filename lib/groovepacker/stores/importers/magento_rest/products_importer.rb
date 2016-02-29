module Groovepacker
  module Stores
    module Importers
      module MagentoRest
        class ProductsImporter < Groovepacker::Stores::Importers::Importer
          include ProductsHelper

          def import
            handler = self.get_handler
            credential = handler[:credential]
            if credential.store_version=='2.x'
              result = Groovepacker::Stores::Importers::MagentoRest::V2::ProductsImporter.new(handler).import
            else
              result = Groovepacker::Stores::Importers::MagentoRest::V1::ProductsImporter.new(handler).import
            end
            result
          end

          def import_single(product_attrs={})
            handler = self.get_handler
            credential = handler[:credential]
            if credential.store_version=='2.x'
              result = Groovepacker::Stores::Importers::MagentoRest::V2::ProductsImporter.new(handler).import_single(product_attrs)
            else
              result = Groovepacker::Stores::Importers::MagentoRest::V1::ProductsImporter.new(handler).import_single(product_attrs)
            end
            result
          end
        end
      end
    end
  end
end
