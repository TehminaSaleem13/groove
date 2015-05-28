class ProductLot < ActiveRecord::Base
  attr_accessible :lot_number, :product_id, :qty, :order_item_id
  has_many :order_item_order_serial_product_lots
  belongs_to :product
end
