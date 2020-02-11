module Groovepacker
  module Stores
    class Context
      def initialize(handler)
        self.handler = handler
      end

      def import_products
        self.handler.import_products
      end

      def import_order(order)
        self.handler.import_order(order)
      end

      def import_orders
        self.handler.import_orders
      end

      def import_images
        self.handler.import_images
      end

      def update_product(hash)
        self.handler.update_product(hash)
      end

      def verify_tags(tags)
        self.handler.verify_tags(tags)
      end

      def verify_awaiting_tags(tags)
        self.handler.verify_awaiting_tags(tags)
      end

      def update_all_products
        self.handler.update_all_products
      end

      def pull_inventory
        self.handler.pull_inventory
      end

      def push_inventory
        self.handler.push_inventory
      end

      def pull_single_product_inventory(product)
        self.handler.pull_single_product_inventory(product)
      end

      def import_bc_single_product(product, pull_inv=true)
        self.handler.import_bc_single_product(product, pull_inv)
      end

      def import_teapplix_single_product(product)
        self.handler.import_teapplix_single_product(product)
      end

      def import_shopify_single_product(product)
        self.handler.import_single_product(product)
      end

      def import_single_order_from(order_no)
        self.handler.import_single_order_from(order_no)
      end

      def import_single_order_from_ss_rest(order_no, user_id, on_demand_quickfix = nil, controller = nil)
        self.handler.import_single_order_from(order_no, user_id, on_demand_quickfix, controller)
      end

      def find_or_create_product(item)
        self.handler.find_or_create_product(item)
      end

      def range_import_for_ss(start_date, end_date, type)
        self.handler.range_import_for_ss(start_date, end_date, type )
      end

      def quick_fix_import(import_date, order_id)
        self.handler.quick_fix_import(import_date, order_id)
      end

      attr_accessor :handler
    end
  end
end
