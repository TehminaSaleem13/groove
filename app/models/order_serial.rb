class OrderSerial < ActiveRecord::Base
  belongs_to :order
  belongs_to :product
  attr_accessible :serial, :order_id, :product_id
  has_many :order_item_order_serial_product_lots
end
