class RemoveUniquenessProductBarcode < ActiveRecord::Migration
  def up
    remove_index :product_barcodes, :barcode
  end

  def down
    add_index :product_barcodes, :barcode
  end
end
