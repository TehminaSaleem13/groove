module Groovepacker
  module Store
    module Importers
      module Shipstation
        class OrdersImporter < Groovepacker::Store::Importers::Importer
          def import
            handler = self.get_handler
            credential = handler[:credential]
            shipstation = handler[:store_handle]
            result = self.build_result
            
            begin
              
            rescue Exception => e
              result[:status] &= false
              result[:messages].push(e)
            end
            result
          end

          def import_single(hash)
            {}
          end

          
        end
      end
    end
  end
end