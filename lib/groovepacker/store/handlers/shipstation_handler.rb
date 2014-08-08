module Groovepacker
  module Store
    module Handlers
      class ShipstationHandler < Handler
        def build_handle
          shipstation_credential = ShipstationCredential.where(:store_id => self.store.id).first

          if !shipstation_credential.nil?
            ShipStationRuby.username  = "dreadhead"
            ShipStationRuby.password  = "g8J$v5KLoP"
            client = ShipStationRuby::Client.new
          end
            
          self.make_handle(shipstation_credential, client)
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