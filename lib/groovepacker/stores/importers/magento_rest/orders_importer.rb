module Groovepacker
  module Stores
    module Importers
      module MagentoRest
        class OrdersImporter < Groovepacker::Stores::Importers::Importer
          
          def import
            handler = self.get_handler
            credential = handler[:credential]
            if credential.store_version=='2.x'
							result = Groovepacker::Stores::Importers::MagentoRest::V2::OrdersImporter.new(handler).import
						else
							result = Groovepacker::Stores::Importers::MagentoRest::V1::OrdersImporter.new(handler).import
						end
            update_orders_status
            result
          end
          
        end
      end
    end
  end
end
