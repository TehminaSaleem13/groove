class AddIsDefaultToInventoryWarehouses < ActiveRecord::Migration
  def up
    add_column :inventory_warehouses, :is_default, :boolean, :default => 0
  end
  def down
  	remove_column :inventory_warehouses, :is_default
  end
end
