# frozen_string_literal: true

module Groovepacker
  module Stores
    module Handlers
      class TeapplixHandler < Handler
        def build_handle
          teapplix_credential = TeapplixCredential.find_by_store_id(store.id)
          client = Groovepacker::Teapplix::Client.new(teapplix_credential) if teapplix_credential
          make_handle(store.teapplix_credential, client)
        end

        def import_orders
          Groovepacker::Stores::Importers::Teapplix::OrdersImporter.new(
            build_handle
          ).import
        end

        def import_products
          Groovepacker::Stores::Importers::Teapplix::ProductsImporter.new(
            build_handle
          ).import
        end

        def pull_inventory
          Groovepacker::Stores::Importers::Teapplix::Inventory.new(
            build_handle
          ).pull_inventories
        end

        def push_inventory
          Groovepacker::Stores::Exporters::Teapplix::Inventory.new(
            build_handle
          ).push_inventories
        end

        def pull_single_product_inventory(product)
          Groovepacker::Stores::Importers::Teapplix::Inventory.new(
            build_handle
          ).pull_single_product_inventory(product)
        end

        def import_teapplix_single_product(product)
          Groovepacker::Stores::Importers::Teapplix::ProductsImporter.new(
            build_handle
          ).import_teapplix_single_product(product)
        end
      end
    end
  end
end
