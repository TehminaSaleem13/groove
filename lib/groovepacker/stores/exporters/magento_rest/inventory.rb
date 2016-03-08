module Groovepacker
  module Stores
    module Exporters
      module MagentoRest
        class Inventory < Groovepacker::Stores::Importers::Importer
          include ProductsHelper

          def push_inventories
            handler = self.get_handler
            creds = handler[:credential]
            if creds.store_version=='1.x'
              exporter = Groovepacker::Stores::Exporters::MagentoRest::V1::Inventory.new(handler)
            else
              exporter = Groovepacker::Stores::Exporters::MagentoRest::V2::Inventory.new(handler)
            end
            result = exporter.push_inventories
          end
          
        end
      end
    end
  end
end
