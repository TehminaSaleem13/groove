# frozen_string_literal: true

module Groovepacker
  module Stores
    module Handlers
      require 'mws-connect'
      class AmazonHandler < Handler
        def build_handle
          amazon_credential = AmazonCredentials.where(store_id: store.id).first
          mws = nil
          unless amazon_credential.nil?
            mws = MWS.new(aws_access_key_id: ENV['AMAZON_MWS_ACCESS_KEY_ID'],
                          secret_access_key: ENV['AMAZON_MWS_SECRET_ACCESS_KEY'],
                          seller_id: amazon_credential.merchant_id,
                          marketplace_id: amazon_credential.marketplace_id,
                          MWS_auth_token: amazon_credential.mws_auth_token)

            mws_alternate = Mws.connect(
              merchant: amazon_credential.merchant_id,
              access: ENV['AMAZON_MWS_ACCESS_KEY_ID'],
              secret: ENV['AMAZON_MWS_SECRET_ACCESS_KEY'],
              marketplace_id: amazon_credential.marketplace_id,
              MWS_auth_token: amazon_credential.mws_auth_token
            )
          end

          make_handle(amazon_credential, main_handle: mws,
                                         alternate_handle: mws_alternate)
        end

        def import_products
          Groovepacker::Stores::Importers::Amazon::ProductsImporter.new(
            build_handle
          ).import
        end

        def import_orders
          Groovepacker::Stores::Importers::Amazon::OrdersImporter.new(
            build_handle
          ).import
        end

        def update_product
          Groovepacker::Stores::Updaters::Amazon::ProductUpdater.new(
            build_handle
          ).import
        end
      end
    end
  end
end
