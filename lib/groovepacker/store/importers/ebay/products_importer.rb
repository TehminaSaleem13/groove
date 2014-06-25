module Groovepacker
  module Store
    module Importers
      module Ebay
        class ProductsImporter < Groovepacker::Store::Importers::Importer
          def import
            {
              :handler => get_handler,
              :status => "ebay ok"
            }
          end

          def import_single(hash)
            {}
          end
        end
      end
    end
  end
end