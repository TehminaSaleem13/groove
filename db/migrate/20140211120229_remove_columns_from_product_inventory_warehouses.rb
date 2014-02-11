class RemoveColumnsFromProductInventoryWarehouses < ActiveRecord::Migration
  def up
  	# remove_column :product_inventory_warehouses, :location
  	# remove_column :product_inventory_warehouses, :name
  	add_column :product_inventory_warehouses, :inventory_warehouse_id, :integer, references: :inventory_warehouses
  	add_index :product_inventory_warehouses, :inventory_warehouse_id
  end

  def down
  	remove_index :product_inventory_warehouses, :inventory_warehouse_id
  	remove_column :product_inventory_warehouses, :inventory_warehouse_id
  	# add_column :product_inventory_warehouses, :name, :string
  	# add_column :product_inventory_warehouses, :location, :string
  end
end
