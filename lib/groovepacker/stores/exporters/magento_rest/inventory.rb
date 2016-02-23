module Groovepacker
  module Stores
    module Exporters
      module MagentoRest
        class Inventory < Groovepacker::Stores::Importers::Importer
          include ProductsHelper

          def push_inventories
            handler = self.get_handler
            credential = handler[:credential]
            if credential.store_version=='2.x'
              result = Groovepacker::Stores::Exporters::MagentoRest::V2::Inventory.new(handler).push_inventories
            else
              result = Groovepacker::Stores::Exporters::MagentoRest::V1::Inventory.new(handler).push_inventories
            end
            result
          end
        end
      end
    end
  end
end
