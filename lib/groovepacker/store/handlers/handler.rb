module Groovepacker
  module Store
    module Handlers
      class Handler
        def initialize(store,import_item = nil)
          self.store = store
          if import_item.nil?
            import_item = Groovepacker::Store::Handlers::MockImportItem.new
          end
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
            store_handle: store_handle,
            import_item: self.import_item
          }
        end
      end

      class MockImportItem
        attr_accessor :to_import, :import_type, :current_increment_id, :current_order_items, :current_order_imported_item, :message, 
        :success_imported, :previous_imported, :status
        def initialize

        end

        def save

        end

        def reload
        end
      end
    end
  end
end
