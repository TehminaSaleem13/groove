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
      end
    end
  end
end
