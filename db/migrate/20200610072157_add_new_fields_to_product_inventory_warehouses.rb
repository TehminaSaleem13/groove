class AddNewFieldsToProductInventoryWarehouses < ActiveRecord::Migration[5.1]
  def change
    add_column :product_inventory_warehouses, :location_quaternary, :string, :limit => 50 unless column_exists? :product_inventory_warehouses, :location_quaternary
    add_column :product_inventory_warehouses, :location_primary_qty, :integer unless column_exists? :product_inventory_warehouses, :location_primary_qty
    add_column :product_inventory_warehouses, :location_secondary_qty, :integer unless column_exists? :product_inventory_warehouses, :location_secondary_qty
    add_column :product_inventory_warehouses, :location_tertiary_qty, :integer unless column_exists? :product_inventory_warehouses, :location_tertiary_qty
    add_column :product_inventory_warehouses, :location_quaternary_qty, :integer unless column_exists? :product_inventory_warehouses, :location_quaternary_qty
  end
end
