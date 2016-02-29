module Groovepacker
  module Stores
    module Importers
      module MagentoRest
        class Inventory < Groovepacker::Stores::Importers::Importer
          include ProductsHelper

          def pull_inventories
            handler = self.get_handler
            result = get_inventory_importer(handler).pull_inventories            
          end

          private
            def get_inventory_importer(handler)
              credential = handler[:credential]
              if credential.store_version=='2.x'
                importer = Groovepacker::Stores::Importers::MagentoRest::V2::Inventory.new(handler)
                return importer
              end
              importer = Groovepacker::Stores::Importers::MagentoRest::V1::Inventory.new(handler)
            end
        end
      end
    end
  end
end
