module Groovepacker
  module Store
    module Importers
      module Amazon
        class ProductsImporter < Groovepacker::Store::Importers::Importer
          def import
            {
              :handler => get_handler,
              :status => "amazon ok"
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