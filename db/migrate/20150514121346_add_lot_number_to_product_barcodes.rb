class AddLotNumberToProductBarcodes < ActiveRecord::Migration[5.1]
  def change
    add_column :product_barcodes, :lot_number, :string
  end
end
