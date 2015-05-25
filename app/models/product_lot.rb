class ProductLot < ActiveRecord::Base
  attr_accessible :lot_number, :product_id
  has_one :order_item
  belongs_to :product
end
