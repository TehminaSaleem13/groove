class AddShipStationCoulumnsToOrders < ActiveRecord::Migration
  def up
  	add_column :orders, :order_number, :string
  	add_column :orders, :seller_id, :integer
  	add_column :orders, :order_status_id, :integer
  	add_column :orders, :ship_name, :string
  	add_column :orders, :shipping_amount, :decimal, :precision => 9, :scale => 2, :default => '0'
  	add_column :orders, :order_total, :decimal, :precision => 9, :scale => 2, :default => '0'
  	add_column :orders, :notes_from_buyer, :string
  	add_column :orders, :weight_oz, :integer
  end
  def down
  	remove_column :orders, :order_number
  	remove_column :orders, :seller_id
  	remove_column :orders, :order_status_id
  	remove_column :orders, :ship_name
  	remove_column :orders, :shipping_amount
  	remove_column :orders, :order_total
  	remove_column :orders, :notes_from_buyer
  	remove_column :orders, :weight_oz
  end
end
