class AddInvAlertLevelToProductInventoryWarehouse < ActiveRecord::Migration[5.1]
  def change
    add_column :product_inventory_warehouses, :product_inv_alert_level, :integer, :default => 0
    add_column :product_inventory_warehouses, :product_inv_alert, :boolean, :default => 0
  end
end
