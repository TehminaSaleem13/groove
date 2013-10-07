class Order < ActiveRecord::Base
  belongs_to :store
  attr_accessible :customercomments, :status, :storename, :store_order_id
  has_many :order_items
  has_one :order_shipping
  attr_accessible :address_1, :address_2, :city, :country, :customer_comments, :email, :firstname, :increment_id, :lastname, :method, :order_placed_time, :postcode, :price, :qty, :sku, :state, :store_id
end
