module Groovepacker
  module Stores
    module Handlers
      class MagentoHandler < Handler
        def build_handle
          magento_credential = MagentoCredentials.where(:store_id => self.store.id).first unless MagentoCredentials.where(:store_id => self.store.id).empty?
          client = nil
          session = nil
          if !magento_credential.nil?
            5.times do
              if magento_credential.updated_patch
                # client = Savon.client( wsdl: magento_credential.host+"/api/soap/?wsdl=1")
                client = Savon.client( wsdl: magento_credential.host+"/api/v2_soap/?wsdl=1")
              else
                client = Savon.client( wsdl: magento_credential.host+"/index.php/api/v2_soap/index/wsdl/1")
              end
              response = client.call(:login, message: {apiUser: magento_credential.username, apikey: magento_credential.api_key}) rescue nil
              begin
                session = response.body[:login_response][:login_return]
                break
              rescue
              end
            end
          end
          self.make_handle(magento_credential, {handle: client, session: session})
        end

        def import_products
          Groovepacker::Stores::Importers::Magento::ProductsImporter.new(
            self.build_handle).import
        end

        def import_orders
          Groovepacker::Stores::Importers::Magento::OrdersImporter.new(
            self.build_handle).import
        end
      end
    end
  end
end
