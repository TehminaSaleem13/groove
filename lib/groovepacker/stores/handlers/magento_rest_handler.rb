module Groovepacker
  module Stores
    module Handlers
      class MagentoRestHandler < Handler
        def build_handle
          
          magento_rest_credential = MagentoRestCredential.where(:store_id => self.store.id).first 
          client = nil
          session = nil

          if !magento_rest_credential.blank?
            if magento_rest_credential.store_version=="2.x"
              client = Groovepacker::MagentoRestV2::Client.new(magento_rest_credential)
            else
              client = Groovepacker::MagentoRest::Client.new(magento_rest_credential)
            end
          end

          self.make_handle(magento_rest_credential, {handle: client})
        end

        def import_products
          Groovepacker::Stores::Importers::MagentoRest::ProductsImporter.new(
            self.build_handle).import
        end

        def import_orders
          Groovepacker::Stores::Importers::MagentoRest::OrdersImporter.new(
            self.build_handle).import
        end

        def pull_inventory
          Groovepacker::Stores::Importers::MagentoRest::Inventory.new(
            self.build_handle).pull_inventories
        end

        def push_inventory
          Groovepacker::Stores::Exporters::MagentoRest::Inventory.new(
            self.build_handle).push_inventories
        end

      end
    end
  end
end
