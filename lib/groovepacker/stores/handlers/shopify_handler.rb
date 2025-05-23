# frozen_string_literal: true

module Groovepacker
  module Stores
    module Handlers
      class ShopifyHandler < Handler
        def build_handle
          shopify_credential = ShopifyCredential.where(store_id: store.id).first

          client = Groovepacker::ShopifyRuby::Client.new(shopify_credential) unless shopify_credential.nil?

          make_handle(shopify_credential, client)
        end

        def import_orders
          Groovepacker::Stores::Importers::ShopifyShoplineImporter.new(
            build_handle
          ).import
        end

        def import_single_order_from(order_no, user_id)
          Groovepacker::Stores::Importers::ShopifyShoplineImporter.new(
            build_handle
          ).ondemand_import_single_order(order_no, user_id)
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
          Groovepacker::Stores::Exporters::Shopify::Inventory.new(
            build_handle
          ).push_inventories
        end

        def import_single_product(product)
          Groovepacker::Stores::Importers::ShopProductsImporter.new(
            build_handle
          ).import_single_product(product)
        end

        def import_single_shopify_product_as_source(product, sku)
          Groovepacker::Stores::Importers::ShopProductsImporter.new(
            build_handle
          ).import_single_shopify_product_as_source(product, sku)
        end
      end
    end
  end
end
