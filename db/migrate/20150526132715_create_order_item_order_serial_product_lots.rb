class CreateOrderItemOrderSerialProductLots < ActiveRecord::Migration
  def up
    create_table :order_item_order_serial_product_lots do |t|
      t.integer :order_item_id
      t.integer :product_lot_id
      t.integer :order_serial_id

      t.timestamps
    end
  end
  def down
  	drop_table :order_item_order_serial_product_lots
  end
end
