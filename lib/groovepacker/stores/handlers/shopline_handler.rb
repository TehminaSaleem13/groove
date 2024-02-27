# frozen_string_literal: true

module Groovepacker
  module Stores
    module Handlers
      class ShoplineHandler < Handler
        def build_handle
          shopline_credential = ShoplineCredential.where(store_id: store.id).first

          client = Groovepacker::ShoplineRuby::Client.new(shopline_credential) unless shopline_credential.nil?

          make_handle(shopline_credential, client)
        end

        def import_orders
          Groovepacker::Stores::Importers::ShopifyShoplineImporter.new(
            build_handle
          ).import
        end

        def import_single_order_from(order_no)
          Groovepacker::Stores::Importers::ShopifyShoplineImporter.new(
            build_handle
          ).ondemand_import_single_order(order_no)
        end

        def import_products(product_import_type, product_import_range_days)
          Groovepacker::Stores::Importers::ShopProductsImporter.new(
            build_handle
          ).import(product_import_type, product_import_range_days)
        end

        def pull_inventory
          Groovepacker::Stores::Importers::ShopInventoryImporter.new(
            build_handle
          ).pull_inventories
        end

        def push_inventory
          Groovepacker::Stores::Exporters::Shopline::Inventory.new(
            build_handle
          ).push_inventories
        end

        def import_single_product(product)
          Groovepacker::Stores::Importers::ShopProductsImporter.new(
            build_handle
          ).import_single_product(product)
        end
      end
    end
  end
end
