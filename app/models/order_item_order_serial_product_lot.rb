class OrderItemOrderSerialProductLot < ActiveRecord::Base
  # attr_accessible :order_item_id, :order_serial_id, :product_lot_id, :qty
  belongs_to :order_item, optional: true
  belongs_to :order_serial, optional: true
  belongs_to :product_lot, optional: true
  #===========================================================================================
  #please update the delete_orders library if adding before_destroy or after_destroy callback
  # or adding dependent destroy for associated models
  #===========================================================================================
end
