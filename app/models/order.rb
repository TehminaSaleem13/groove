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
  	if @activity.save
  		true
  	else
  		false
  	end
  end

  def addnewitems
    @order_items = OrderItem.where(:order_id=>self.id)
    result = true

    @order_items.each do |item|
      #add new product if item is not added.
      if ProductSku.where(:sku=>item.sku).length == 0
        product = Product.new
        product.name = item.name
        product.status = 'New'
        product.store_id = self.store_id
        product.store_product_id = 0
        
        if product.save            
          #now add skus
          @sku = ProductSku.new
          @sku.sku = item.sku
          @sku.purpose = 'primary'
          @sku.product_id = product.id
          if !@sku.save
            result &= false
          end
        end
      end
    end
    result
  end

end
