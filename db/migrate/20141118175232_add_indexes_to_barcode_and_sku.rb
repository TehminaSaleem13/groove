class AddIndexesToBarcodeAndSku < ActiveRecord::Migration
  def change
    add_index :product_skus, :sku
    add_index :product_barcodes, :barcode
  end
end
