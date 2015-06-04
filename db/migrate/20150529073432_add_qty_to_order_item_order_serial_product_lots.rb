class AddQtyToOrderItemOrderSerialProductLots < ActiveRecord::Migration
  def up
    add_column :order_item_order_serial_product_lots, :qty, :integer, :default => 0
  end

  def down
  	remove_column :order_item_order_serial_product_lots, :qty
  end
end
