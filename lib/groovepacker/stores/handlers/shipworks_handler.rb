module Groovepacker
  module Stores
    module Handlers
      class ShipworksHandler < Handler
        def build_handle
          self.make_handle(self.store.shipworks_credential, self.store)
        end

        def import_order(order)
          Groovepacker::Stores::Importers::Shipworks::OrdersImporter.new(
            self.build_handle).import_order(order)
        end
      end
    end
  end
end
