class OrderSerial < ActiveRecord::Base
  belongs_to :order
  belongs_to :product
  attr_accessible :serial
  has_many :order_item_order_serial_product_lots
end
