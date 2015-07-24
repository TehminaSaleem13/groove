class InventoryUpdateChanges < ActiveRecord::Migration
  def up
    add_column :sold_inventory_warehouses, :order_item_id ,:integer
    add_index :sold_inventory_warehouses, :order_item_id
    remove_column :orders, :update_inventory_level
    add_column :orders, :reallocate_inventory, :boolean, :default => false
    remove_column :general_settings, :inventory_auto_allocation
  end

  def down
    remove_index :sold_inventory_warehouses, :order_item_id
    remove_column :sold_inventory_warehouses, :order_item_id
    add_column :orders, :update_inventory_level, :boolean, :default => true
    remove_column :orders, :reallocate_inventory, :boolean
    add_column :general_settings, :inventory_auto_allocation, :boolean, :default => false
  end
end
