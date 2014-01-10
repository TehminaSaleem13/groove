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

      if result
        if self.status == "onhold"
         self.status = "awaiting"
        end
      else
        if self.status == "awaiting"
         self.status = "onhold"
        end
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

  def contains_kit
    result = false
    self.order_items.each do |order_item|
      if order_item.product.is_kit == 1
        result = true
        break
      end
    end
    result
  end

  def contains_splittable_kit
    result = false
    self.order_items.each do |order_item|
      if order_item.product.is_kit == 1 &&
          order_item.product.kit_parsing == 'depends'
        result = true
        break
      end
    end
    result
  end

  def does_barcode_belong_to_individual_kit(barcode)
    result = false
    barcode_found = false
    product_inside_kit = false
    matched_product_id = 0

    product_barcode = ProductBarcode.where(:barcode=>barcode)
    
    if product_barcode.length > 0
      product_barcode = product_barcode.first
      self.order_items.each do |order_item|
        if order_item.product_id == product_barcode.product.id
          barcode_found = true
          matched_product_id = order_item.product_id 
        end

        if !barcode_found
          order_item.order_item_kit_products.each do |kit|
            if kit.product_kit_skus.product.id == product_barcode.product.id
              barcode_found = true
              matched_kit_id = product_kit_skus.product.id
              matched_product_id = kit.id
            end
          end
        end
      end
    end

    if barcode_found
      if Product.find(matched_product_id).kit_parsing == 'individual'
        result = true
      end
    end
    result
  end

  def should_the_kit_be_split(barcode)
    result = false
    product_inside_splittable_kit = false
    product_available_as_single_item = false
    matched_product_id = 0
    matched_order_item_id = 0
    product_barcode = ProductBarcode.where(:barcode=>barcode)
    
    if product_barcode.length > 0
      product_barcode = product_barcode.first
    else
      product_barcode = nil
    end
    puts "Product Barcode:" +product_barcode.barcode
    #check if barcode is present in a kit which has kitparsing of depends
    if !product_barcode.nil?
      self.order_items.each do |order_item|
        if order_item.product.is_kit == 1 && order_item.product.kit_parsing == 'depends' && 
          order_item.scanned_status != 'scanned'
          order_item.product.product_kit_skuss.each do |kit_product|
            puts "Product Id:" + kit_product.option_product_id.to_s
            puts "Product Barcode Id:" + product_barcode.product_id.to_s
            if kit_product.option_product_id == product_barcode.product_id
              product_inside_splittable_kit = true
              matched_product_id = kit_product.option_product_id
              matched_order_item_id = order_item.id
              result = true
              break
            end
          end
        end
        break if product_inside_splittable_kit
      end
    end
    puts "Product inside splittable kit:"+product_inside_splittable_kit.to_s
    #if barcode is present and the matched product is also present in other non-kit
    #and unscanned order items, then the kit need not be split.
    if product_inside_splittable_kit 
      self.order_items.each do |order_item|
        puts "Order Kit Status:"+order_item.product.is_kit.to_s
        puts "Order Item Status:"+order_item.scanned_status
        if order_item.product.is_kit == 0 && order_item.scanned_status != 'scanned'
            puts "Order Product Id:" + order_item.product_id.to_s
            puts "Product Barcode Id:" + matched_product_id.to_s
          if order_item.product_id == matched_product_id
            product_available_as_single_item = true
            result = false
            break
          end
        end
        break if product_available_as_single_item
      end
    end

    if result 
      order_item = OrderItem.find(matched_order_item_id)
      order_item.kit_split = true
      order_item.save
      puts "Order Item"+order_item.id.to_s
      order_item.reload
      puts "Kit Split"+order_item.kit_split.to_s+"Id: "+order_item.id.to_s
    end
    puts "Product available as single item:"+product_available_as_single_item.to_s
    result
  end

  def get_unscanned_items
    unscanned_list = []
    #Order.connection.clear_query_cache
    self.reload
    self.order_items.each do |order_item|
      if order_item.scanned_status != 'scanned'
        puts "Kit Status:"+order_item.product.is_kit.to_s
        if order_item.product.is_kit == 1
          puts "Kit Parsing:" + order_item.product.kit_parsing
          puts "Before:"+unscanned_list.to_s
          if order_item.product.kit_parsing == 'single'
            #if single, then add order item to unscanned list  
            unscanned_list.push(order_item.build_unscanned_single_item)
          elsif order_item.product.kit_parsing == 'individual'
            #else if individual then add all order items as children to unscanned list
            unscanned_list.push(order_item.build_unscanned_individual_kit)
          elsif order_item.product.kit_parsing == 'depends'
            puts "Kit Split"+order_item.kit_split.to_s+"Id: "+order_item.id.to_s
            if order_item.kit_split
              unscanned_list.push(order_item.build_unscanned_individual_kit)
            else
              unscanned_list.push(order_item.build_unscanned_single_item)
            end
          end
          puts "After:"+unscanned_list.to_s
        else
          # add order item to unscanned list
          unscanned_list.push(order_item.build_unscanned_single_item)
        end
      end
    end
    unscanned_list.sort_by { |hsh| hsh['packing_placement'] }
  end
  def get_scanned_items
    scanned_list = []

    self.order_items.each do |order_item|
      if order_item.scanned_status == 'scanned' ||
          order_item.scanned_status == 'partially_scanned'
        if order_item.product.is_kit == 1
          if order_item.product.kit_parsing == 'single'
            #if single, then add order item to unscanned list  
            scanned_list.push(order_item.build_scanned_single_item)
          elsif order_item.product.kit_parsing == 'individual'
            #else if individual then add all order items as children to unscanned list
            scanned_list.push(order_item.build_scanned_individual_kit)
          elsif order_item.product.kit_parsing == 'depends'
            if order_item.kit_split
              scanned_list.push(order_item.build_scanned_individual_kit)
            else
              scanned_list.push(order_item.build_scanned_single_item)
            end
          end
        else
          # add order item to unscanned list
          scanned_list.push(order_item.build_unscanned_single_item)
        end
      end
    end
    scanned_list
  end

  def reset_scanned_status
    self.order_items.each do |order_item|
      #if item is a kit then make all order item product skus as also unscanned
      if order_item.product.is_kit == 1
        order_item.order_item_kit_products.each do |kit_product|
          kit_product.scanned_status = 'unscanned'
          kit_product.scanned_qty = 0
          kit_product.save
        end
      end

      order_item.scanned_status = 'unscanned'
      order_item.scanned_qty = 0
      order_item.save
    end

    self.status = 'awaiting'
    self.save
  end
end
