module Groovepacker
  module Stores
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
          Groovepacker::Stores::Importers::ShipstationRest::ProductsImporter.new(
            self.build_handle).import
        end

        def import_orders
          Groovepacker::Stores::Importers::ShipstationRest::OrdersImporter.new(
            self.build_handle).import
        end

        def import_images
          Groovepacker::Stores::Importers::ShipstationRest::ImagesImporter.new(
            self.build_handle).import
        end

        def update_product(hash)
          Groovepacker::Stores::Updaters::ShipstationRest::ProductsUpdater.new(
            self.build_handle).update_single(hash[:product], hash[:store_order_id])
        end

        def update_all_products
          Groovepacker::Stores::Updaters::ShipstationRest::ProductsUpdater.new(
            self.build_handle).update_all
        end

        def verify_tags(tags)
          Groovepacker::Stores::Utilities::ShipstationRest::Utilities.new(
            self.build_handle).verify_tags(tags)
        end

        def import_single_order_from(order_no)
          Groovepacker::Stores::Importers::ShipstationRest::OrdersImporter.new(
            self.build_handle).import_single_order(order_no)
        end

        def find_or_create_product(item)
          Groovepacker::Stores::Importers::ShipstationRest::OrderProductImporter.new(
            self.build_handle).find_or_create_product(item)
        end
        
      end
    end
  end
end
