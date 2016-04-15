class OrderSerial < ActiveRecord::Base
  belongs_to :order
  belongs_to :product
  attr_accessible :serial, :order_id, :product_id
  has_many :order_item_order_serial_product_lots
  #===========================================================================================
  #please update the delete_orders library if adding before_destroy or after_destroy callback
  # or adding dependent destroy for associated models
  #===========================================================================================
end
