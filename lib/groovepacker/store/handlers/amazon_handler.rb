module Groovepacker
  module Store
    module Handlers
      class AmazonHandler < Handler
        def build_handle
          {
            handle: "ok",
            store: store
          }
        end

        def import_products
          handle = self.build_handle
        end

        def import_orders
          handle = self.build_handle
          importer = Groovepacker::Store::Importers::Amazon::OrdersImporter.new(handle)
          importer.import
        end
      end
    end
  end
end