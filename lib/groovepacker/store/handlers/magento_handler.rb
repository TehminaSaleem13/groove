module Groovepacker
  module Store
    module Handlers
      class MagentoHandler < Handler
        def build_handle
          magento_credential = 
            MagentoCredentials.where(:store_id => self.store.id).first  unless
             MagentoCredentials.where(:store_id => self.store.id).empty?
          client = nil
          session = nil

          if !magento_credential.nil?
            client = 
              Savon.client(
                wsdl: magento_credential.host+"/index.php/api/v2_soap/index/wsdl/1"
              )

            response = client.call(:login,  
              message: { 
                apiUser: magento_credential.username,
                apikey: magento_credential.api_key })

            session = response.body[:login_response][:login_return]
          end
            
          self.make_handle(magento_credential, {handle: client, session: session})
        end

        def import_products
          Groovepacker::Store::Importers::Magento::ProductsImporter.new(
            self.build_handle).import
        end

        def import_orders
          Groovepacker::Store::Importers::Magento::OrdersImporter.new(
            self.build_handle).import
        end
      end
    end
  end
end
