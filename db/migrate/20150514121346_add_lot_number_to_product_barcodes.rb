class AddLotNumberToProductBarcodes < ActiveRecord::Migration
  def change
    add_column :product_barcodes, :lot_number, :string
  end
end
