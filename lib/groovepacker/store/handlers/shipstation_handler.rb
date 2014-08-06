module Groovepacker
  module Store
    module Handlers
      class ShipstationHandler < Handler
        def build_handle
          
        end

        def import_products
          Groovepacker::Store::Importers::Shipstation::ProductsImporter.new(
            self.build_handle).import
        end

        def import_orders
          Groovepacker::Store::Importers::Shipstation::OrdersImporter.new(
            self.build_handle).import
        end
      end
    end
  end
end