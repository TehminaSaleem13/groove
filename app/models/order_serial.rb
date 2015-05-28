class OrderSerial < ActiveRecord::Base
  belongs_to :order
  belongs_to :product
  attr_accessible :serial
  has_and_belongs_to_many :product_lots
end
