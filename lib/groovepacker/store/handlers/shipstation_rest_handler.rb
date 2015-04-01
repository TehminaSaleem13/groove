module Groovepacker
  module Store
    module Handlers
      class ShipstationRestHandler < Handler
        def build_handle
          shipstation_rest_credential = ShipstationRestCredential.where(:store_id => self.store.id).first

          if !shipstation_rest_credential.nil?
            client = Groovepacker::ShipstationRuby::Rest::Client.new(shipstation_rest_credential.api_key,
              shipstation_rest_credential.api_secret)
          end
            
          self.make_handle(shipstation_rest_credential, client)
        end

        def import_products
          Groovepacker::Store::Importers::ShipstationRest::ProductsImporter.new(
            self.build_handle).import
        end

        def import_orders
          Groovepacker::Store::Importers::ShipstationRest::OrdersImporter.new(
            self.build_handle).import
        end

        def import_images
          Groovepacker::Store::Importers::ShipstationRest::ImagesImporter.new(
            self.build_handle).import
        end

        def update_product(hash)
          Groovepacker::Store::Updaters::ShipstationRest::ProductsUpdater.new(
            self.build_handle).update_single(hash[:product], hash[:store_order_id])
        end

        def update_all_products
          Groovepacker::Store::Updaters::ShipstationRest::ProductsUpdater.new(
            self.build_handle).update_all
        end

        def verify_tags(tags)
          Groovepacker::Store::Utilities::ShipstationRest::Utilities.new(
            self.build_handle).verify_tags(tags)
        end
      end
    end
  end
end