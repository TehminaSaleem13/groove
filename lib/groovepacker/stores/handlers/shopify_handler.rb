module Groovepacker
  module Stores
    module Handlers
      class ShopifyHandler < Handler
        def build_handle
          shopify_credential = ShopifyCredential.where(:store_id => self.store.id).first

          if !shopify_credential.nil?
            client = Groovepacker::ShopifyRuby::Client.new(shopify_credential)
          end

          self.make_handle(shopify_credential, client)
        end

        def import_orders
          Groovepacker::Stores::Importers::Shopify::OrdersImporter.new(
            self.build_handle).import
        end
        
        def pull_inventory
          Groovepacker::Stores::Importers::Shopify::Inventory.new(
            self.build_handle).pull_inventories
        end

        def push_inventory
          Groovepacker::Stores::Exporters::Shopify::Inventory.new(
            self.build_handle).push_inventories
        end
        
      end
    end
  end
end
