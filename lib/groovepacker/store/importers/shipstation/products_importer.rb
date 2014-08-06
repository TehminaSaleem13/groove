module Groovepacker
  module Store
    module Importers
      module Shipstation
        class ProductsImporter < Groovepacker::Store::Importers::Importer
          def import
            #do ebay connect.
            handler = self.get_handler
            credential = handler[:credential]
            shipstation = handler[:store_handle]
            result = self.build_result

            begin
              
            end
            result
          end
        end
      end
    end
  end
end