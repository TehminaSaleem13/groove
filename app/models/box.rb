class Box < ActiveRecord::Base
  attr_accessible :name, :order_id
  has_many :order_items
end
