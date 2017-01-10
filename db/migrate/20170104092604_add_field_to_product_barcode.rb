class AddFieldToProductBarcode < ActiveRecord::Migration
  def change
  	add_column :product_barcodes, :is_multipack_barcode, :boolean, :default => false
  end
end

