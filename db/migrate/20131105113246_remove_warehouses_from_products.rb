class RemoveWarehousesFromProducts < ActiveRecord::Migration
  def up
  	remove_column :products, :inv_alert_wh1
    remove_column :products, :inv_wh2_qty
    remove_column :products, :inv_alert_wh2
    remove_column :products, :inv_wh3_qty
    remove_column :products, :inv_alert_wh3
    remove_column :products, :inv_wh4_qty
    remove_column :products, :inv_alert_wh4
    remove_column :products, :inv_wh5_qty
    remove_column :products, :inv_alert_wh5
    remove_column :products, :inv_wh6_qty
    remove_column :products, :inv_alert_wh6
    remove_column :products, :inv_wh7_qty
    remove_column :products, :inv_alert_wh7
    add_column :product_inventory_warehouses, :alert, :string
  end

  def down
  	remove_column :product_inventory_warehouses, :alert
  	add_column :products, :inv_alert_wh1, :integer
    add_column :products, :inv_wh2_qty, :integer
    add_column :products, :inv_alert_wh2, :integer
    add_column :products, :inv_wh3_qty, :integer
    add_column :products, :inv_alert_wh3, :integer
    add_column :products, :inv_wh4_qty, :integer
    add_column :products, :inv_alert_wh4, :integer
    add_column :products, :inv_wh5_qty, :integer
    add_column :products, :inv_alert_wh5, :integer
    add_column :products, :inv_wh6_qty, :integer
    add_column :products, :inv_alert_wh6, :integer
    add_column :products, :inv_wh7_qty, :integer
    add_column :products, :inv_alert_wh7, :integer
  end
end
