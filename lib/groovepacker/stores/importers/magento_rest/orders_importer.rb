# frozen_string_literal: true

module Groovepacker
  module Stores
    module Importers
      module MagentoRest
        class OrdersImporter < Groovepacker::Stores::Importers::Importer
          def import
            handler = get_handler
            credential = handler[:credential]
            result = if credential.store_version == '2.x'
                       Groovepacker::Stores::Importers::MagentoRest::V2::OrdersImporter.new(handler).import
                     else
                       Groovepacker::Stores::Importers::MagentoRest::V1::OrdersImporter.new(handler).import
                     end
            update_orders_status
            result
          end
        end
      end
    end
  end
end
