class RemoveSoldInventoryColumnsFromProductInventoryWarehouses < ActiveRecord::Migration
  def up
  	remove_column :product_inventory_warehouses, :sold_date
  	remove_column :product_inventory_warehouses, :sold_inv
  end

  def down
    add_column :product_inventory_warehouses, :sold_inv, :integer, :default=>0, :null=>false
    add_column :product_inventory_warehouses, :sold_date, :timestamp
  end
end
