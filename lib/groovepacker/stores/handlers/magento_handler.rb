# frozen_string_literal: true

module Groovepacker
  module Stores
    module Handlers
      class MagentoHandler < Handler
        def build_handle
          magento_credential = MagentoCredentials.where(store_id: store.id).first unless MagentoCredentials.where(store_id: store.id).empty?
          client = nil
          session = nil
          unless magento_credential.nil?
            5.times do
              client = if magento_credential.updated_patch
                         # client = Savon.client( wsdl: magento_credential.host+"/api/soap/?wsdl=1")
                         Savon.client(wsdl: magento_credential.host + '/api/v2_soap/?wsdl=1')
                       else
                         Savon.client(wsdl: magento_credential.host + '/index.php/api/v2_soap/index/wsdl/1')
                       end
              response = begin
                           client.call(:login, message: { apiUser: magento_credential.username, apikey: magento_credential.api_key })
                         rescue StandardError
                           nil
                         end
              begin
                session = response.body[:login_response][:login_return]
                break
              rescue StandardError
              end
            end
          end
          make_handle(magento_credential, handle: client, session: session)
        end

        def import_products
          Groovepacker::Stores::Importers::Magento::ProductsImporter.new(
            build_handle
          ).import
        end

        def import_orders
          Groovepacker::Stores::Importers::Magento::OrdersImporter.new(
            build_handle
          ).import
        end
      end
    end
  end
end
