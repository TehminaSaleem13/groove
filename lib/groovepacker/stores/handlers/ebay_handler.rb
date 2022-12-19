# frozen_string_literal: true

module Groovepacker
  module Stores
    module Handlers
      class EbayHandler < Handler
        def build_handle
          ebay_credential = EbayCredentials.where(store_id: store.id).first
          mws = nil

          unless ebay_credential.nil?
            require 'eBayAPI'

            sandbox = ENV['EBAY_SANDBOX_MODE'] == 'YES'

            ebay = EBay::API.new(ebay_credential.auth_token,
                                 ENV['EBAY_DEV_ID'], ENV['EBAY_APP_ID'],
                                 ENV['EBAY_CERT_ID'], sandbox: sandbox)
          end

          make_handle(ebay_credential, ebay)
        end

        def import_products
          Groovepacker::Stores::Importers::Ebay::ProductsImporter.new(
            build_handle
          ).import
        end

        def import_orders
          Groovepacker::Stores::Importers::Ebay::OrdersImporter.new(
            build_handle
          ).import
        end
      end
    end
  end
end
