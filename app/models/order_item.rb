class OrderItem < ActiveRecord::Base
  belongs_to :order
  belongs_to :product
  attr_accessible :price, :qty, :row_total, :sku
end
