module Groovepacker
  module Stores
    module Handlers
      class MagentoRestHandler < Handler
        def build_handle
          
          magento_rest_credential = MagentoRestCredential.where(:store_id => self.store.id).first 
          client = nil
          session = nil

          if !magento_rest_credential.blank?
            client = Groovepacker::MagentoRest::Client.new(magento_rest_credential)
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
      end
    end
  end
end
