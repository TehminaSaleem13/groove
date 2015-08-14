module Groovepacker
  module Stores
    module Handlers
      class EbayHandler < Handler
        def build_handle
          ebay_credential = EbayCredentials.where(:store_id => self.store.id).first
          mws = nil

          if !ebay_credential.nil?
            require 'eBayAPI'
            
            if ENV['EBAY_SANDBOX_MODE'] == 'YES'
              sandbox = true
            else
              sandbox = false
            end

            ebay = EBay::API.new(ebay_credential.auth_token,
              ENV['EBAY_DEV_ID'], ENV['EBAY_APP_ID'],
              ENV['EBAY_CERT_ID'], :sandbox=>sandbox)
          end
            
          self.make_handle(ebay_credential, ebay)
        end

        def import_products
          Groovepacker::Stores::Importers::Ebay::ProductsImporter.new(
            self.build_handle).import
        end

        def import_orders
          Groovepacker::Stores::Importers::Ebay::OrdersImporter.new(
            self.build_handle).import
        end
      end
    end
  end
end
