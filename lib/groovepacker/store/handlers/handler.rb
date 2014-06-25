module Groovepacker
  module Store
    module Handlers
      class Handler
        def initialize(store)
          self.store = store
        end

        def build_handle
          "ok"
        end

        def import_products
          {}
        end

        def import_orders
          {}
        end

        protected
          attr_accessor :store
      end
    end
  end
end