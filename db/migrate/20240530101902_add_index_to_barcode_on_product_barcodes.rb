class AddIndexToBarcodeOnProductBarcodes < ActiveRecord::Migration[5.1]
  def change
    add_index :product_barcodes, [:barcode]
  end
end
