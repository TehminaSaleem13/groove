module Groovepacker
  module Store
    module Handlers
      class Handler
        def initialize(store,import_item = nil)
          self.store = store
          self.import_item = import_item
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
        
        def import_order(order)
          {}
        end

        def import_images
          {}
        end

        def update_single(hash)
          {}
        end

        protected
          attr_accessor :store,:import_item

        def make_handle(credential, store_handle)
          {
            credential: credential,
            store_handle: store_handle
          }
        end
      end
    end
  end
end
