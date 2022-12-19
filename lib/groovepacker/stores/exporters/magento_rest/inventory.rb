# frozen_string_literal: true

module Groovepacker
  module Stores
    module Exporters
      module MagentoRest
        class Inventory < Groovepacker::Stores::Importers::Importer
          include ProductsHelper

          def push_inventories
            handler = get_handler
            creds = handler[:credential]
            exporter = if creds.store_version == '1.x'
                         Groovepacker::Stores::Exporters::MagentoRest::V1::Inventory.new(handler)
                       else
                         Groovepacker::Stores::Exporters::MagentoRest::V2::Inventory.new(handler)
                       end
            result = exporter.push_inventories
          end
        end
      end
    end
  end
end
