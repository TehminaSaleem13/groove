# frozen_string_literal: true

module Groovepacker
  module Stores
    module Handlers
      class ShipstationRestHandler < Handler
        def build_handle
          shipstation_rest_credential = ShipstationRestCredential.where(store_id: store.id).first

          unless shipstation_rest_credential.nil?
            client = Groovepacker::ShipstationRuby::Rest::Client.new(shipstation_rest_credential.api_key,
                                                                     shipstation_rest_credential.api_secret)
          end

          make_handle(shipstation_rest_credential, client)
        end

        def import_products
          Groovepacker::Stores::Importers::ShipstationRest::ProductsImporter.new(
            build_handle
          ).import
        end

        def import_orders
          # if @store.regular_import_v2 == true
          #   Groovepacker::Stores::Importers::ShipstationRest::OrdersImporterNew.new(
          #     self.build_handle).import
          # else
          #   Groovepacker::Stores::Importers::ShipstationRest::OrdersImporter.new(
          #     self.build_handle).import
          # end
          Groovepacker::Stores::Importers::ShipstationRest::OrdersImporterNew.new(
            build_handle
          ).import
        end

        def import_images
          Groovepacker::Stores::Importers::ShipstationRest::ImagesImporter.new(
            build_handle
          ).import
        end

        def update_product(hash)
          Groovepacker::Stores::Updaters::ShipstationRest::ProductsUpdater.new(
            build_handle
          ).update_single(hash[:product], hash[:store_order_id])
        end

        def update_all_products
          Groovepacker::Stores::Updaters::ShipstationRest::ProductsUpdater.new(
            build_handle
          ).update_all
        end

        def verify_tags(tags)
          Groovepacker::Stores::Utilities::ShipstationRest::Utilities.new(
            build_handle
          ).verify_tags(tags)
        end

        def verify_awaiting_tags(_gp_ready_tag_name)
          Groovepacker::Stores::Importers::ShipstationRest::OrdersImporter.new(
            build_handle
          ).verify_awaiting_tags
        end

        def import_single_order_from(order_no, user_id, on_demand_quickfix, controller)
          # if @store.on_demand_import_v2 == true
          #   Groovepacker::Stores::Importers::ShipstationRest::OrdersImporterNew.new(
          #     self.build_handle).import_single_order(order_no, user_id, on_demand_quickfix, controller)
          # else
          #   Groovepacker::Stores::Importers::ShipstationRest::OrdersImporter.new(
          #     self.build_handle).import_single_order(order_no)
          # end
          Groovepacker::Stores::Importers::ShipstationRest::OrdersImporterNew.new(
            build_handle
          ).import_single_order(order_no, user_id, on_demand_quickfix, controller)
        end

        def find_or_create_product(item)
          Groovepacker::Stores::Importers::ShipstationRest::OrderProductImporter.new(
            build_handle
          ).find_or_create_product(item)
        end

        def range_import(start_date, end_date, type, current_user_id)
          Groovepacker::Stores::Importers::ShipstationRest::OrdersImporterNew.new(
            build_handle
          ).range_import(start_date, end_date, type, current_user_id)
        end

        def quick_fix_import(import_date, order_id, current_user_id)
          Groovepacker::Stores::Importers::ShipstationRest::OrdersImporterNew.new(
            build_handle
          ).quick_fix_import(import_date, order_id, current_user_id)
        end
      end
    end
  end
end
