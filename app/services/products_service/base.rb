# frozen_string_literal: true

module ProductsService
  class Base < ServiceInit
    require 'barby'
    require 'barby/barcode/code_128'
    require 'barby/outputter/png_outputter'
    require 'mws-connect'

    def preload_associations(products)
      ActiveRecord::Associations::Preloader.new.preload(
        products,
        [
          :product_barcodes, :product_skus, :product_cats, :product_images,
          :store, :product_kit_skuss, product_inventory_warehousess: [:inventory_warehouse]
        ]
      )
    end
  end
end
