class AddColumnToProductBarcode < ActiveRecord::Migration[5.1]
  def change
  	add_column :product_barcodes, :packing_count, :string
  end
end
