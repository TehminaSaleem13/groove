module Groovepacker
  module Stores
    module Importers
      module MagentoRest
        class Inventory < Groovepacker::Stores::Importers::Importer
          include ProductsHelper

          def pull_inventories
            handler = self.get_handler
            credential = handler[:credential]
            if credential.store_version=='2.x'
              result = Groovepacker::Stores::Importers::MagentoRest::V2::Inventory.new(handler).pull_inventories
            else
              result = Groovepacker::Stores::Importers::MagentoRest::V1::Inventory.new(handler).pull_inventories
            end
          end
          
        end
      end
    end
  end
end
