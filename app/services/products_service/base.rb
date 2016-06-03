module ProductsService
  class Base < ServiceInit
    require 'barby'
    require 'barby/barcode/code_128'
    require 'barby/outputter/png_outputter'
    require 'mws-connect'

    def preload_associations(products)
      ActiveRecord::Associations::Preloader.new(
        products,
        [
          :product_barcodes, :product_skus, :product_cats, :product_images,
          :store, :product_kit_skuss, :product_inventory_warehousess
        ]
      ).run
    end
  end
end
