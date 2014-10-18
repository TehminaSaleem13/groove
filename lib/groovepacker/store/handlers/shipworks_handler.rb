module Groovepacker
  module Store
    module Handlers
      class ShipworksHandler < Handler
        # def import_products
        #   Groovepacker::Store::Importers::Shipworks::ProductsImporter.new(
        #     self.build_handle).import
        # end

        def import_order(order)
          Groovepacker::Store::Importers::Shipworks::OrdersImporter.new(
            order).import_order(order)
        end

        # def import_images
        #   Groovepacker::Store::Importers::Shipworks::ImagesImporter.new(
        #     self.build_handle).import
        # end

        # def update_product(hash)
        #   Groovepacker::Store::Updaters::Shipworks::ProductsUpdater.new(
        #     self.build_handle).update_single(hash)
        # end
      end
    end
  end
end