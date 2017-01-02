class AddColumnToProductBarcode < ActiveRecord::Migration
  def change
  	add_column :product_barcodes, :packing_count, :string
  end
end
