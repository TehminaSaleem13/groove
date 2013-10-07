class OrderItem < ActiveRecord::Base
  belongs_to :order
  attr_accessible :price, :qty, :row_total, :sku
end
