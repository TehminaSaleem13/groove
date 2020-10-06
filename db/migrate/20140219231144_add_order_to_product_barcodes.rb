class AddOrderToProductBarcodes < ActiveRecord::Migration[5.1]
  def change
    add_column :product_barcodes, :order, :integer, :default=>0
  end
end
