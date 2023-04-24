module Groovepacker
  module Stores
    module Handlers
      class ShippoHandler < Handler
        def build_handle
          shippo_credential = ShippoCredential.where(store_id: store.id).first

          client = Groovepacker::ShippoRuby::Client.new(shippo_credential) unless shippo_credential.nil?

          make_handle(shippo_credential, client)
        end

        def import_orders
          Groovepacker::Stores::Importers::Shippo::OrdersImporter.new(
            build_handle
          ).import
        end

        def import_single_order_from(order_no)
          Groovepacker::Stores::Importers::Shippo::OrdersImporter.new(
            build_handle
          ).ondemand_import_single_order(order_no)
        end

        def range_import(start_date, end_date, type, current_user_id)
          Groovepacker::Stores::Importers::Shippo::OrdersImporter.new(
            build_handle
          ).range_import(start_date, end_date, type, current_user_id)
        end
      end
    end
  end
end
