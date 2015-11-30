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

      attr_accessor :handler
    end
  end
end
