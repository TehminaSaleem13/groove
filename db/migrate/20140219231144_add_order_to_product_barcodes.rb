class AddOrderToProductBarcodes < ActiveRecord::Migration
  def change
    add_column :product_barcodes, :order, :integer, :default=>0
  end
end
