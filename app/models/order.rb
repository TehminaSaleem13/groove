class Order < ActiveRecord::Base
  belongs_to :store
  attr_accessible :customercomments, :status, :storename
  attr_accessible :address_1, :address_2, :city, :country, :customer_comments, :email, :firstname, :increment_id, :lastname, 
  		:method, :order_placed_time, :postcode, :price, :qty, :sku, :state, :store_id, :notes_internal, 
  		:notes_toPacker, :notes_fromPacker, :tracking_processed, :scanned_on, :tracking_num, :company
  has_many :order_items
  has_one :order_shipping
end
