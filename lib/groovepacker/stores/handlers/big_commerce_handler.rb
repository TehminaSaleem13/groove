module Groovepacker
  module Stores
    module Handlers
      class BigCommerceHandler < Handler
        def build_handle
          big_commerce_credential = BigCommerceCredential.where(:store_id => self.store.id).first
          if !big_commerce_credential.nil?
            client = Groovepacker::BigCommerceRuby::Client.new(big_commerce_credential)
          end
          self.make_handle(self.store.big_commerce_credential, client)
        end

        def import_orders
          Groovepacker::Stores::Importers::BigCommerce::OrdersImporter.new(
            self.build_handle).import
        end
        
        def pull_inventory
          Groovepacker::Stores::Importers::BigCommerce::Inventory.new(
            self.build_handle).pull_inventories
        end

        def push_inventory
          Groovepacker::Stores::Exporters::BigCommerce::Inventory.new(
            self.build_handle).push_inventories
        end
      end
    end
  end
end