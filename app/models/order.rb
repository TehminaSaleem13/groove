class Order < ActiveRecord::Base
  belongs_to :store
  attr_accessible :customercomments, :status, :storename, :store_order_id, :store, :order_total
  attr_accessible :address_1, :address_2, :city, :country, :customer_comments, :email, :firstname,
  :increment_id, :lastname,
  		:method, :order_placed_time, :postcode, :price, :qty, :sku, :state, :store_id, :notes_internal,
  		:notes_toPacker, :notes_fromPacker, :tracking_processed, :scanned_on, :tracking_num, :company,
      :packing_user_id, :status_reason, :non_hyphen_increment_id

  has_many :order_items, :dependent => :destroy
  has_one :order_shipping, :dependent => :destroy
  has_one :order_exceptions, :dependent => :destroy
  has_many :order_activities, :dependent => :destroy
  has_many :order_serials, :dependent => :destroy
  has_and_belongs_to_many :order_tags
  after_update :update_inventory_levels_for_items
  before_save :update_non_hyphen_increment_id
  validates_uniqueness_of :increment_id

  include ProductsHelper
  include OrdersHelper
  include ApplicationHelper

  def addactivity(order_activity_message, username='', activity_type ='regular')
  	@activity = OrderActivity.new
  	@activity.order_id = self.id
  	@activity.action = order_activity_message
  	@activity.username = username
    @activity.activitytime = current_time_from_proper_timezone
    @activity.activity_type = activity_type
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

  def set_order_to_scanned_state(username)
    self.status = 'scanned'
    self.scanned_on = current_time_from_proper_timezone
    self.addactivity('Order Scanning Complete', username)
    self.save
    restriction = AccessRestriction.order("created_at").last
    unless restriction.nil?
      restriction.total_scanned_shipments += 1
      restriction.save
    end
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
          if product.status == "new" or product.status == "inactive" or 
            (GeneralSetting.first.hold_orders_due_to_inventory and (order_item.inv_status == 'unallocated' or order_item.inv_status == 'unprocessed'))
              result &= false
              puts "result: " + result.inspect
          end
        end
      end

      result &= false if self.unacknowledged_activities.length > 0

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

      self.apply_and_update_predefined_tags
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
    
    result &= false if self.unacknowledged_activities.length > 0
    
    if result
      self.status = "awaiting"
    else
      self.status = "onhold"
    end

    self.save
    self.apply_and_update_predefined_tags
  end

  def has_unscanned_items
    result = false
    self.reload
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
    #puts "Product Barcode:" +product_barcode.barcode
    #check if barcode is present in a kit which has kitparsing of depends
    if !product_barcode.nil?
      self.order_items.each do |order_item|
        if order_item.product.is_kit == 1 && order_item.product.kit_parsing == 'depends' &&
          order_item.scanned_status != 'scanned'
          order_item.product.product_kit_skuss.each do |kit_product|
            #puts "Product Id:" + kit_product.option_product_id.to_s
            #puts "Product Barcode Id:" + product_barcode.product_id.to_s
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
    #puts "Product inside splittable kit:"+product_inside_splittable_kit.to_s
    #if barcode is present and the matched product is also present in other non-kit
    #and unscanned order items, then the kit need not be split.
    if product_inside_splittable_kit
      self.order_items.each do |order_item|
        #puts "Order Kit Status:"+order_item.product.is_kit.to_s
        #puts "Order Item Status:"+order_item.scanned_status
        if order_item.product.is_kit == 0 && order_item.scanned_status != 'scanned'
            #puts "Order Product Id:" + order_item.product_id.to_s
            #puts "Product Barcode Id:" + matched_product_id.to_s
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
      if order_item.kit_split == true

        #if current item does not belong to any of the unscanned items in the already split kits
        if order_item.should_kit_split_qty_be_increased(matched_product_id)
          if order_item.kit_split_qty <= order_item.qty
            logger.info 'Kit is already split, incrementing quantity'
            order_item.kit_split_qty = order_item.kit_split_qty + 1
            order_item.order_item_kit_products.each do |kit_product|
              kit_product.scanned_status = 'partially_scanned'
              kit_product.save
            end
          end
        end
      else
        order_item.kit_split = true
        order_item.kit_split_qty = 1
      end
      order_item.save
      #puts "Order Item"+order_item.id.to_s
      order_item.reload
      #puts "Kit Split"+order_item.kit_split.to_s+"Id: "+order_item.id.to_s
    end
    #puts "Product available as single item:"+product_available_as_single_item.to_s
    result
  end

  def get_unscanned_items
    unscanned_list = []
    #Order.connection.clear_query_cache
    self.reload
    self.order_items.each do |order_item|
      if order_item.scanned_status != 'scanned'
        #puts "Kit Status:"+order_item.product.is_kit.to_s
        if order_item.product.is_kit == 1
          #puts "Kit Parsing:" + order_item.product.kit_parsing
          #puts "Before:"+unscanned_list.to_s
          if order_item.product.kit_parsing == 'single'
            #if single, then add order item to unscanned list
            unscanned_list.push(order_item.build_unscanned_single_item)
          elsif order_item.product.kit_parsing == 'individual'
            #else if individual then add all order items as children to unscanned list
            unscanned_list.push(order_item.build_unscanned_individual_kit)
          elsif order_item.product.kit_parsing == 'depends'
            #puts "Kit Split"+order_item.kit_split.to_s+"Id: "+order_item.id.to_s
            if order_item.kit_split
              if order_item.kit_split_qty > order_item.kit_split_scanned_qty
                unscanned_list.push(order_item.build_unscanned_individual_kit(true))
              end
              if order_item.qty > order_item.kit_split_qty
                unscanned_item = order_item.build_unscanned_single_item(true)
                if unscanned_item['qty_remaining'] > 0
                  unscanned_list.push(unscanned_item)
                end
              end
              # unscanned_qty = order_item.qty - order_item.scanned_qty
              # added_to_list_qty = true
              # unscanned_qty.times do
              #   if added_to_list_qty < unscanned_qty
              #     individual_kit_count = 0

              #     #determine no of split kits already in unscanned_list
              #     unscanned_list.each do |unscanned_item|
              #       if unscanned_item['product_id'] == order_item.product_id &&
              #           unscanned_item['product_type'] == 'individual'
              #           individual_kit_count = individual_kit_count + 1
              #       end
              #     end

              #     logger.info 'Individual Kit Count'+individual_kit_count.to_s
              #     logger.info 'Kit Split Quantity'+order_item.kit_split_qty.to_s

              #     #unscanned list building kits
              #     if individual_kit_count < order_item.kit_split_qty
              #       unscanned_list.push(order_item.build_unscanned_individual_kit, true)
              #       added_to_list_qty = added_to_list_qty + order_item.kit_split_qty
              #     else
              #       unscanned_list.push(order_item.build_unscanned_single_item, true)
              #     end
              #   end
              # end
            else
              unscanned_item = order_item.build_unscanned_single_item
              if unscanned_item['qty_remaining'] > 0
                unscanned_list.push(unscanned_item)
              end
            end
          end
          #puts "After:"+unscanned_list.to_s
        else
          # add order item to unscanned list
          unscanned_item = order_item.build_unscanned_single_item
          if unscanned_item['qty_remaining'] > 0
            unscanned_list.push(unscanned_item)
          end
        end
      end
    end
    logger.info unscanned_list.to_s
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
              if order_item.kit_split_qty > 0
                scanned_list.push(order_item.build_scanned_individual_kit(true))
              end
              if order_item.single_scanned_qty != 0
                scanned_list.push(order_item.build_scanned_single_item(true))
              end
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

    #transform scanned_list to move all child items into displaying as individual items
    scanned_list.each do |scanned_item|
      if scanned_item['product_type'] == 'individual'
        scanned_item['child_items'].each do |child_item|
          if child_item['scanned_qty'] > 0
            found_single_item = false
            #for each child item, check if the child item already exists in list of single items
            #in the scanned list. If so, then add this child items scanned quantity to the single items quantity
            scanned_list.each do |single_scanned_item|
              if single_scanned_item['product_type'] == 'single'
                if single_scanned_item['product_id'] == child_item['product_id']
                  single_scanned_item['scanned_qty'] = single_scanned_item['scanned_qty'] +
                      child_item['scanned_qty']
                  found_single_item = true
                end
              end
            end

            #if not found, then add this child item as a new single item
            if !found_single_item
              new_item = build_pack_item(child_item['name'], 'single', child_item['images'], child_item['sku'],
                child_item['qty_remaining'],
                child_item['scanned_qty'], child_item['packing_placement'], child_item['barcodes'],
                child_item['product_id'], scanned_item['order_item_id'], nil,child_item['instruction'],child_item['confirmation'],child_item['skippable'], child_item['record_serial'])
              scanned_list.push(new_item)
            end
          end
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
      order_item.kit_split = false
      order_item.kit_split_qty = 0
      order_item.kit_split_scanned_qty = 0
      order_item.single_scanned_qty = 0
      order_item.save
    end

    self.order_serials.destroy_all
    self.set_order_status
    self.tracking_num = ''
    self.update_inventory_levels_for_items(true)
    self.save
  end

  def addtag(tag_id)
    result = false

    tag = OrderTag.find(tag_id)

    if !tag.nil? && (!self.order_tags.include? tag)
      self.order_tags << tag
      self.save
      result = true
    end

    result
  end

  def removetag(tag_id)
    result = false

    tag = OrderTag.find(tag_id)

    if !tag.nil? && (self.order_tags.include? tag)
      self.order_tags.delete(tag)
      self.save
      result = true
    end

    result
  end

  def apply_and_update_predefined_tags

    #apply contains new tag, if any of the order items contain new products
    contains_new_tag = OrderTag.where(:name=>'Contains New')
    contains_new_tag = contains_new_tag.first if contains_new_tag.length > 0
    if !contains_new_tag.nil?
      contains_new = false

      self.order_items.each do |order_item|
        if !order_item.product.nil? && order_item.product.status == 'new'
          contains_new = true
        end
      end

      # if contains_new
      #   self.addtag(contains_new_tag.id)
      # else
      #   self.removetag(contains_new_tag.id)
      # end
    end

    #apply contains inactive tag, if any of the order items contain inactive products
    contains_inactive_tag = OrderTag.where(:name=>'Contains Inactive')
    contains_inactive_tag = contains_inactive_tag.first if contains_inactive_tag.length > 0
    if !contains_inactive_tag.nil?
      contains_inactive = false

      self.order_items.each do |order_item|
        if !order_item.product.nil? && order_item.product.status == 'inactive'
          contains_inactive = true
          break
        end
      end

      # if contains_inactive
      #   self.addtag(contains_inactive_tag.id)
      # else
      #   self.removetag(contains_inactive_tag.id)
      # end
    end

    self.save

  end
  def get_items_count
    count = 0
    unless self.order_items.empty?
      self.order_items.each do |item|
        count = count + item.qty unless item.qty.nil?
      end
    end
    count
  end

  def update_inventory_levels_for_items(override = true)
    changed_hash = self.changes
    logger.debug(changed_hash)
    if self.update_inventory_level
      unless changed_hash['status'].nil?
        if (changed_hash['status'][0] == 'onhold' or
            changed_hash['status'][0] == 'cancelled' or override) and
           (changed_hash['status'][1] == 'awaiting' or
            changed_hash['status'][1] == 'serviceissue')
          #update_inventory_levels_for_purchase
          reason = 'packing'
        elsif (changed_hash['status'][0] == 'awaiting' or
          changed_hash['status'][0] == 'serviceissue') and
          (changed_hash['status'][1] == 'onhold' or
          changed_hash['status'][1] == 'cancelled')
          #update_inventory_levels_for_return
          reason = 'return'
        elsif changed_hash['status'][0] == 'onhold' and changed_hash['status'][1] == 'cancelled'
          reason = 'return'
        end
        self.order_items.each do |order_item|
          if reason == 'packing'
            order_item.update_inventory_levels_for_packing(true)
          elsif reason == 'return'
            order_item.update_inventory_levels_for_return(true)
          end
        end
      end

      unless changed_hash['status'].nil?
        #if changing for awaiting to scanned
          if changed_hash['status'][0] == 'awaiting' and
            changed_hash['status'][1] == 'scanned'
            result = true
            #move items from allocated to sold for each order items
            self.order_items.each do |order_item|
              result &= order_item.product.update_allocated_product_sold_level(self.store.inventory_warehouse_id,
              order_item.qty, order_item)
            end

            logger.info('error updating sold inventory level') if !result
          end
      end
    end
  end

  def update_inventory_levels_for_status_change(override = true)
    changed_hash = self.changes
    unless changed_hash['status'].nil?
      if GeneralSetting.first.inventory_auto_allocation
        if (changed_hash['status'][0] == 'serviceissue' or
            changed_hash['status'][0] == 'awaiting') and
            changed_hash['status'][1] == 'scanned'
          result = true
          self.order_items.each do |order_item|
            result &= order_item.product.update_allocated_product_sold_level(self.store.inventory_warehouse_id,
            order_item.qty, order_item)
          end
        elsif changed_hash['status'][0] == 'cancelled' and 
          changed_hash['status'][1] == 'scanned'
          result =true
          self.order_items.each do |order_item|
            result &= order_item.update_inventory_levels_for_packing(true)
            if result
              result &= order_item.product.update_allocated_product_sold_level(self.store.inventory_warehouse_id,
               order_item.qty, order_item)
            end
          end
        end
      # else
      #   if (changed_hash['status'][0] == 'service issue' or
      #       changed_hash['status'][0] == 'awaiting') and
      #     changed_hash['status'][1] == 'scanned'
      #     result = true
      #     self.order_items.each do |order_item|
      #       result &= order_item.update_inventory_levels_for_return(true)
      #     end
      #   elsif changed_hash['status'][0] == 'cancelled' and
      #     (changed_hash['status'][1] == 'scanned')
      #     result = true
      #   end
      end
    end
    logger.info('error updating inventory level') if !result
  end

  def update_non_hyphen_increment_id
    self.non_hyphen_increment_id = non_hyphenated_string(self.increment_id)
  end

  def scanned_items_count
    count = 0
      self.order_items.each do |item|
        if item.product.is_kit
          if item.product.kit_parsing == 'depends'
            count = count + item.single_scanned_qty
            item.order_item_kit_products.each do |kit_product|
              count = count + kit_product.scanned_qty
            end
          elsif item.product.kit_parsing == 'individual'
            item.order_item_kit_products.each do |kit_product|
              count = count + kit_product.scanned_qty
            end
          else
            count = count + item.scanned_qty
          end
        else
          count = count + item.scanned_qty
        end
      end
    count
  end

  def clicked_items_count
    count = 0
      self.order_items.each do |item|
        if item.product.is_kit
          if item.product.kit_parsing == 'depends'
            count = count + item.clicked_qty
            item.order_item_kit_products.each do |kit_product|
              count = count + kit_product.clicked_qty
            end
          elsif item.product.kit_parsing == 'individual'
            item.order_item_kit_products.each do |kit_product|
              count = count + kit_product.clicked_qty
            end
          else
            count = count + item.clicked_qty
          end
        else
          count = count + item.clicked_qty
        end
      end
    count
  end

  def unacknowledged_activities
    order_activities.
      where('activity_type in (:types)', types: 'deleted_item').
      where(acknowledged: false)
  end
end
