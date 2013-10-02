class Order < ActiveRecord::Base
  belongs_to :store
  attr_accessible :customercomments, :status, :storename, :store_order_id
  has_many :order_items
  has_one :order_shipping
end
