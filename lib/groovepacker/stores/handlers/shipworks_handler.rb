# frozen_string_literal: true

module Groovepacker
  module Stores
    module Handlers
      class ShipworksHandler < Handler
        def build_handle
          make_handle(store.shipworks_credential, store)
        end

        def import_order(order)
          Groovepacker::Stores::Importers::Shipworks::OrdersImporter.new(
            build_handle
          ).import_order(order)
        end
      end
    end
  end
end
