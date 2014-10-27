module Groovepacker
  module Store
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

      attr_accessor :handler
    end
  end
end
