class ProductLot < ActiveRecord::Base
  attr_accessible :lot_number, :product_id, :qty, :order_item_id
  has_and_belongs_to_many :order_items
  has_and_belongs_to_many :order_serials
  belongs_to :product
end
