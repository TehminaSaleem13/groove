class AddSoldItemsToProductInventoryWarehouses < ActiveRecord::Migration
  def change
    add_column :product_inventory_warehouses, :sold_inv, :integer, :default=>0, :null=>false
    add_column :product_inventory_warehouses, :sold_date, :timestamp
  end
end
