# frozen_string_literal: true

module Groovepacker
  module Stores
    class Context
      def initialize(handler)
        self.handler = handler
      end

      def import_products
        handler.import_products
      end

      # for Shopify
      def import_shopify_products(product_import_type, product_import_range_days)
        handler.import_products(product_import_type, product_import_range_days)
      end

      # for Shopline
      def import_shopline_products(product_import_type, product_import_range_days)
        handler.import_products(product_import_type, product_import_range_days)
      end

      def import_order(order)
        handler.import_order(order)
      end

      def import_orders
        handler.import_orders
      end

      def import_images
        handler.import_images
      end

      def update_product(hash)
        handler.update_product(hash)
      end

      def verify_tags(tags)
        handler.verify_tags(tags)
      end

      def verify_awaiting_tags(tags)
        handler.verify_awaiting_tags(tags)
      end

      def update_all_products
        handler.update_all_products
      end

      def pull_inventory
        handler.pull_inventory
      end

      def push_inventory
        handler.push_inventory
      end

      def pull_single_product_inventory(product)
        handler.pull_single_product_inventory(product)
      end

      def import_bc_single_product(product, pull_inv = true)
        handler.import_bc_single_product(product, pull_inv)
      end

      def import_teapplix_single_product(product)
        handler.import_teapplix_single_product(product)
      end

      # for Shopline and Shopify
      def import_shop_single_product(product)
        handler.import_single_product(product)
      end

      def import_shippo_single_product(product)
        handler.import_single_product(product)
      end

      def import_single_order_from(order_no)
        handler.import_single_order_from(order_no)
      end

      def import_single_order_from_ss_rest(order_no, user_id, on_demand_quickfix = nil, controller = nil)
        handler.import_single_order_from(order_no, user_id, on_demand_quickfix, controller)
      end

      def find_or_create_product(item)
        handler.find_or_create_product(item)
      end

      def range_import(start_date, end_date, type, current_user_id)
        handler.range_import(start_date, end_date, type, current_user_id)
      end

      def quick_fix_import(import_date, order_id, current_user_id)
        handler.quick_fix_import(import_date, order_id, current_user_id)
      end

      attr_accessor :handler
    end
  end
end
