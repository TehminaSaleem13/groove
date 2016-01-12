module Groovepacker
  module Stores
    module Handlers
      class ShippingEasyHandler < Handler
        def build_handle
          shipping_easy_credential = ShippingEasyCredential.find_by_store_id(self.store.id)

          unless shipping_easy_credential.nil?
            client = Groovepacker::ShippingEasy::Client.new(shipping_easy_credential)
          end

          self.make_handle(shipping_easy_credential, client)
        end

        def import_orders
          Groovepacker::Stores::Importers::ShippingEasy::OrdersImporter.new(
            self.build_handle).import
        end

      end
    end
  end
end
