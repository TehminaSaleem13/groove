class CreateProductBarcodes < ActiveRecord::Migration[5.1]
  def change
    create_table :product_barcodes do |t|
      t.references :product
      t.string :barcode

      t.timestamps
    end
    # add_index :product_barcodes, :product_id
  end
end
