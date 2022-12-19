# frozen_string_literal: true

module Groovepacker
  module Stores
    module Handlers
      class Handler
        def initialize(store, import_item = nil)
          self.store = store
          import_item = Groovepacker::Stores::Handlers::MockImportItem.new if import_item.nil?
          self.import_item = import_item
          self.current_tenant = Apartment::Tenant.current
        end

        def build_handle
          'ok'
        end

        def import_products
          {}
        end

        def import_orders
          {}
        end

        def import_order(_order)
          {}
        end

        def import_images
          {}
        end

        def update_single(_hash)
          {}
        end

        protected

        attr_accessor :store, :import_item, :current_tenant

        def make_handle(credential, store_handle)
          {
            credential: credential,
            store_handle: store_handle,
            import_item: import_item,
            current_tenant: current_tenant
          }
        end
      end

      class MockImportItem
        attr_accessor :to_import, :import_type, :current_increment_id, :current_order_items, :current_order_imported_item, :message,
                      :success_imported, :previous_imported, :status

        def initialize; end

        def save; end

        def reload; end
      end
    end
  end
end
