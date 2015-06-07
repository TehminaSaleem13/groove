class OrderItemOrderSerialProductLot < ActiveRecord::Base
  attr_accessible :order_item_id, :order_serial_id, :product_lot_id, :qty
  belongs_to :order_item
  belongs_to :order_serial
  belongs_to :product_lot
end
