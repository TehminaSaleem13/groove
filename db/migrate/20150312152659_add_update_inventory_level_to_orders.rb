class AddUpdateInventoryLevelToOrders < ActiveRecord::Migration
  def change
  	add_column :orders, :update_inventory_level, :boolean, :default=>1
  end
end
