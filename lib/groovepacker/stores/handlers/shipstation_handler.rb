module Groovepacker
  module Stores
    module Handlers
      class ShipstationHandler < Handler
        def build_handle
          shipstation_credential = ShipstationCredential.where(:store_id => self.store.id).first

          if !shipstation_credential.nil?
            ShipStationRuby.username = shipstation_credential.username
            ShipStationRuby.password = shipstation_credential.password
            client = Groovepacker::ShipstationRuby::Client.new
          end

          self.make_handle(shipstation_credential, client)
        end

        def import_products
          Groovepacker::Stores::Importers::Shipstation::ProductsImporter.new(
            self.build_handle).import
        end

        def import_orders
          Groovepacker::Stores::Importers::Shipstation::OrdersImporter.new(
            self.build_handle).import
        end

        def import_images
          Groovepacker::Stores::Importers::Shipstation::ImagesImporter.new(
            self.build_handle).import
        end

        def update_product(hash)
          Groovepacker::Stores::Updaters::Shipstation::ProductsUpdater.new(
            self.build_handle).update_single(hash)
        end
      end
    end
  end
end
