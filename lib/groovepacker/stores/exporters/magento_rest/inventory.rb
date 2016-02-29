module Groovepacker
  module Stores
    module Exporters
      module MagentoRest
        class Inventory < Groovepacker::Stores::Importers::Importer
          include ProductsHelper

          def push_inventories
            handler = self.get_handler
            result = get_inv_exporter(handler).push_inventories
          end

          private
            def get_inv_exporter(handler)
              creds = handler[:credential]
              if creds.store_version=='1.x'
                exporter = Groovepacker::Stores::Exporters::MagentoRest::V1::Inventory.new(handler)
                return exporter
              end
              exporter = Groovepacker::Stores::Exporters::MagentoRest::V2::Inventory.new(handler)
            end

        end
      end
    end
  end
end
