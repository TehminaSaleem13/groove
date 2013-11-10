class Order < ActiveRecord::Base
  belongs_to :store
  attr_accessible :customercomments, :status, :storename
  attr_accessible :address_1, :address_2, :city, :country, :customer_comments, :email, :firstname, :increment_id, :lastname, 
  		:method, :order_placed_time, :postcode, :price, :qty, :sku, :state, :store_id, :notes_internal, 
  		:notes_toPacker, :notes_fromPacker, :tracking_processed, :scanned_on, :tracking_num, :company
  has_many :order_items
  has_one :order_shipping
  has_one :order_exceptions
  has_many :order_activities

  def addactivity (order_activity_message, username)
  	@activity = OrderActivity.new
  	@activity.order_id = self.id
  	@activity.action = order_activity_message
  	@activity.username = username
    @activity.activitytime = current_time_from_proper_timezone
  	if @activity.save
  		true
  	else
  		false
  	end
  end

end
