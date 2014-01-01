class Order < ActiveRecord::Base
  belongs_to :store
  attr_accessible :customercomments, :status, :storename, :store_order_id
  attr_accessible :address_1, :address_2, :city, :country, :customer_comments, :email, :firstname,
  :increment_id, :lastname,
  		:method, :order_placed_time, :postcode, :price, :qty, :sku, :state, :store_id, :notes_internal,
  		:notes_toPacker, :notes_fromPacker, :tracking_processed, :scanned_on, :tracking_num, :company

  has_many :order_items, :dependent => :destroy
  has_one :order_shipping, :dependent => :destroy
  has_one :order_exceptions, :dependent => :destroy
  has_many :order_activities, :dependent => :destroy
  include ProductsHelper
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

  def addnewitems
    @order_items = OrderItem.where(:order_id=>self.id)
    result = true

    @order_items.each do |item|
      #add new product if item is not added.
      if ProductSku.where(:sku=>item.sku).length == 0 &&
        !item.name.nil? && item.name != '' && !item.sku.nil?
        product = Product.new
        product.name = item.name
        product.status = 'new'
        product.store_id = self.store_id
        product.store_product_id = 0

        if product.save
          product.set_product_status
          #now add skus
          @sku = ProductSku.new
          @sku.sku = item.sku
          @sku.purpose = 'primary'
          @sku.product_id = product.id
          if !@sku.save
            result &= false
          end
        end
        item.product_id = product.id
        item.save
        import_amazon_product_details(self.store_id, item.sku, item.product_id)
      else
        item.product_id = ProductSku.where(:sku=>item.sku).first.product_id
        item.save
      end
    end
    result
  end

  def set_order_to_scanned_state
    self.status = 'scanned'
    self.scanned_on = Time.now
    self.save
  end

  def has_inactive_or_new_products
    result = false

    self.order_items.each do |order_item|
      product = Product.find_by_id(order_item.product_id)
      unless product.nil?
        if product.status == "new" or product.status == "inactive"
          result = true
        end
      end
    end

    result
  end

  def get_inactive_or_new_products
    products_list = []

    self.order_items.each do |order_item|
      product = Product.find_by_id(order_item.product_id)
      unless product.nil?
        if product.status == "new" or product.status == "inactive"
            products_list << product
        end
      end
    end

    products_list
  end

  def update_order_status
    result = true
    if true
      self.order_items.each do |order_item|
        product = Product.find_by_id(order_item.product_id)
        unless product.nil?
          if product.status == "new" or product.status == "inactive"
              result &= false
          end
        end
      end

      if result && self.status == "onhold"
        self.status = "awaiting"
      elsif self.status == "awaiting"
        self.status = "onhold"
      end
      
      self.save
    end
  end

  def set_order_status
    result = true

    self.order_items.each do |order_item|
      product = Product.find_by_id(order_item.product_id)
      if !product.nil?
        if product.status == "new" or product.status == "inactive"
            result &= false
        end
      else
        result &= false
      end

    end


    if result
      self.status = "awaiting"
    else
      self.status = "onhold"
    end

    self.save
  end

  def has_unscanned_items
    result = false

    self.order_items.each do |order_item|
      if order_item.scanned_status != 'scanned'
        result |= true
        break
      end
    end

    result
  end

end
