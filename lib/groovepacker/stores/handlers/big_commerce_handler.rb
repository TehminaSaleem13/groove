# frozen_string_literal: true

module Groovepacker
  module Stores
    module Handlers
      class BigCommerceHandler < Handler
        def build_handle
          big_commerce_credential = BigCommerceCredential.where(store_id: store.id).first
          client = Groovepacker::BigCommerceRuby::Client.new(big_commerce_credential) unless big_commerce_credential.nil?
          make_handle(store.big_commerce_credential, client)
        end

        def import_orders
          Groovepacker::Stores::Importers::BigCommerce::OrdersImporter.new(
            build_handle
          ).import
        end

        def import_products
          Groovepacker::Stores::Importers::BigCommerce::ProductsImporter.new(
            build_handle
          ).import
        end

        def pull_inventory
          Groovepacker::Stores::Importers::BigCommerce::Inventory.new(
            build_handle
          ).pull_inventories
        end

        def push_inventory
          Groovepacker::Stores::Exporters::BigCommerce::Inventory.new(
            build_handle
          ).push_inventories
        end

        def pull_single_product_inventory(product)
          Groovepacker::Stores::Importers::BigCommerce::Inventory.new(
            build_handle
          ).pull_single_product_inventory(product)
        end

        def import_bc_single_product(product, pull_inv = true)
          Groovepacker::Stores::Importers::BigCommerce::ProductsImporter.new(
            build_handle
          ).import_bc_single_product(product, pull_inv)
        end

        def import_single_order_from(order_no)
          Groovepacker::Stores::Importers::BigCommerce::OrdersImporter.new(
            build_handle
          ).fetch_order_on_demand(order_no)
        end
      end
    end
  end
end
