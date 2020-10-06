class AddIndexesToBarcodeAndSku < ActiveRecord::Migration[5.1]
  def change
    add_index :product_skus, :sku
    add_index :product_barcodes, :barcode
  end
end
