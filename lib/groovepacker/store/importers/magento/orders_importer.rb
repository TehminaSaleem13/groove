module Groovepacker
  module Store
    module Importers
      module Magento
        class ProductsImporter < Groovepacker::Store::Importers::Importer
          def import
            {
              :handler => get_handler,
              :status => "magento ok"
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