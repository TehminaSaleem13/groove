# frozen_string_literal: true

module Groovepacker
  module Stores
    module Handlers
      class ShippingEasyHandler < Handler
        def build_handle
          shipping_easy_credential = ShippingEasyCredential.find_by_store_id(store.id)

          client = Groovepacker::ShippingEasy::Client.new(shipping_easy_credential) unless shipping_easy_credential.nil?

          make_handle(shipping_easy_credential, client)
        end

        def import_orders
          Groovepacker::Stores::Importers::ShippingEasy::OrdersImporter.new(
            build_handle
          ).import
        end

        def import_single_order_from(order_no, user_id)
          Groovepacker::Stores::Importers::ShippingEasy::OrdersImporter.new(
            build_handle
          ).ondemand_import_single_order(order_no, user_id)
        end

        def range_import(start_date, end_date, type, current_user_id)
          Groovepacker::Stores::Importers::ShippingEasy::OrdersImporter.new(
            build_handle
          ).range_import(start_date, end_date, type, current_user_id)
        end

        def quick_fix_import(import_date, order_id, current_user_id)
          Groovepacker::Stores::Importers::ShippingEasy::OrdersImporter.new(
            build_handle
          ).quick_fix_import(import_date, order_id, current_user_id)
        end
      end
    end
  end
end
