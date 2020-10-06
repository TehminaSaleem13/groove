class RemoveUniquenessProductBarcode < ActiveRecord::Migration[5.1]
  def up
    remove_index :product_barcodes, :barcode
  end

  def down
    add_index :product_barcodes, :barcode
  end
end
