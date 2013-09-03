class Order < ActiveRecord::Base
  attr_accessible :address_1, :address_2, :city, :country, :customer_comments, :email, :firstname, :increment_id, :lastname, :method, :order_placed_time, :postcode, :price, :qty, :sku, :state, :store_id
end
