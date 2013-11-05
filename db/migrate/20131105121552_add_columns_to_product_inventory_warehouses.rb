class AddColumnsToProductInventoryWarehouses < ActiveRecord::Migration
  def change
    add_column :product_inventory_warehouses, :location_primary, :string
    add_column :product_inventory_warehouses, :location_secondary, :string
    add_column :product_inventory_warehouses, :name, :string
    remove_column :products, :location_primary
  end
end
