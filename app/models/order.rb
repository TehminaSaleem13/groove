class Order < ActiveRecord::Base
  belongs_to :store
  # attr_accessible :customercomments, :status, :storename, :store_order_id, :store, :order_total
  # attr_accessible :address_1, :address_2, :city, :country, :customer_comments, :email, :firstname, :increment_id, :lastname,:method, :order_placed_time, :postcode, :price, :qty, :sku, :state, :store_id, :notes_internal, :notes_toPacker, :notes_fromPacker, :tracking_processed, :scanned_on, :tracking_num, :company, :packing_user_id, :status_reason, :non_hyphen_increment_id, :shipping_amount, :weight_oz, :custom_field_one, :custom_field_two, :traced_in_dashboard, :scanned_by_status_change, :status, :scan_start_time, :last_modified, :last_suggested_at, :prime_order_id, :split_from_order_id, :source_order_ids, :cloned_from_shipment_id

  #===========================================================================================
  #please update the delete_orders library if adding before_destroy or after_destroy callback
  # or adding dependent destroy for associated models
  #===========================================================================================
  has_many :order_items, :dependent => :destroy
  has_one :order_shipping, :dependent => :destroy
  has_one :tote, :dependent => :nullify
  has_one :order_exception, :dependent => :destroy
  has_many :order_activities, :dependent => :destroy
  has_many :order_serials, :dependent => :destroy
  has_and_belongs_to_many :order_tags
  after_update :update_inventory_levels_for_items
  before_save :perform_pre_save_checks
  # before_save :unique_order_items
  after_save :process_unprocessed_orders
  after_save :update_tracking_num_value
  after_save :delete_if_order_exist, :if => :check_for_duplicate
  validates_uniqueness_of :increment_id, :if => :check_for_duplicate

  extend OrderClassMethodsHelper
  include ProductsHelper
  include OrdersHelper
  include OrderMethodsHelper
  include ApplicationHelper

  ALLOCATE_STATUSES = ['awaiting', 'onhold', 'serviceissue']
  UNALLOCATE_STATUSES = ['cancelled']
  SOLD_STATUSES = ['scanned']

  def check_for_duplicate
    duplicate_condition  = (self.store.store_type == "ShippingEasy" && self.store.shipping_easy_credential.allow_duplicate_id) || (self.store.store_type == "Shipstation API 2" && self.store.shipstation_rest_credential.allow_duplicate_order)
    duplicate_condition ? false : true
  end

  def customer_name
    [firstname, lastname].join(' ')
  end

  def has_store_and_warehouse?
    !self.store.nil? && self.store.ensure_warehouse?
  end

  def addactivity(order_activity_message, username='', activity_type ='regular')
    @activity = OrderActivity.new
    @activity.order_id = self.id
    @activity.action = order_activity_message
    @activity.username = username
    @activity.activitytime = current_time_from_proper_timezone
    @activity.activity_type = activity_type
    @activity.user_id = User.find_by_username(username).try(:id)
    @activity.user_id = User.find_by_name(username).try(:id) if @activity.user_id.nil?
    @activity.save
  end

  def process_unprocessed_orders
    bulkaction = Groovepacker::Inventory::BulkActions.new
    bulkaction.process_unprocessed
    true
  end

  def update_tracking_num_value
    if self.tracking_num == ""
      self.tracking_num = nil
      self.save
    end
  end

  def addnewitems
    @order_items = OrderItem.where(:order_id => self.id)
    result = true

    @order_items.each do |item|
      #add new product if item is not added.
      if ProductSku.where(:sku => item.sku).length == 0 && !item.name.nil? && item.name != '' && !item.sku.nil?
        add_new_product_for_item(item, result)
      else
        item.product_id = ProductSku.where(:sku => item.sku).first.product_id
        item.save
      end
    end
    result
  end

  def compute_packing_score
    100 - (self.total_scan_time.to_f / self.total_scan_count)
  end

  def set_order_to_scanned_state(username)
    self.status = 'scanned'
    self.already_scanned = true
    self.scanned_on = current_time_from_proper_timezone
    self.addactivity('Order Scanning Complete', username) if !ScanPackSetting.last.order_verification
    self.packing_score = self.compute_packing_score
    self.save
    update_access_restriction
    tenant = Apartment::Tenant.current
    SendStatStream.new.delay(:run_at => 1.seconds.from_now, :queue => 'export_stat_stream_scheduled').build_send_stream(tenant, self.id) if !Rails.env.test? && Tenant.where(name: tenant).last.groovelytic_stat
  end

  def contains_zero_qty_order_item?
    order_items.find do |order_item|
      order_item.qty.eql?(0)
    end.present?
  end

  def contains_zero_qty_order_kit_item?
    order_items.find do |order_item|
      order_item.product.product_kit_skuss.map(&:qty).index(0)
    end.present?
  end

  def update_order_status
    # Implement hold orders from Groovepacker::Inventory
    result = !has_inactive_or_new_products

    result &= false if unacknowledged_activities.length > 0

    if result
      if status == 'onhold'
        self.status = 'awaiting'
        save
      end
    else
      if status == 'awaiting'
        self.status = 'onhold'
        save
      end
    end
    # isn't being used, shouldn't get called
    # self.apply_and_update_predefined_tags
  end

  def set_order_status
    result = !has_inactive_or_new_products

    result &= false if self.unacknowledged_activities.length > 0
    status = result ? 'awaiting' : 'onhold'

    if self.id.present? 
      update_column(:status, status)
      update_column(:scan_start_time, nil)
    else
      self.status = status
      self.scan_start_time = nil
      self.save
    end

    #self.apply_and_update_predefined_tags
  end

  def has_unscanned_items
    result = false
    self.reload
    self.order_items.includes(:product).each do |order_item|
      unless order_item.product.try(:is_intangible)
        if order_item.scanned_status != 'scanned'
          result |= true
          break
        end
      end
    end

    result
  end

  def contains_kit
    result = false
    self.order_items.includes(:product).each do |order_item|
      if order_item.product.is_kit == 1
        result = true
        break
      end
    end
    result
  end

  def contains_splittable_kit
    result = false
    self.order_items.includes(:product).each do |order_item|
      if order_item.product.is_kit == 1 &&
        order_item.product.kit_parsing == 'depends'
        result = true
        break
      end
    end
    result
  end

  def scanning_count
    Order.multiple_orders_scanning_count([self])[self.id]
  end

  def reset_scanned_status(current_user)
    self.order_items.includes([:order_item_kit_products]).each do |order_item|
      order_item.reset_scanned
    end
    self.addactivity('All scanned items removed. Order has been RESET', current_user.try(:name))
    self.order_serials.destroy_all
    self.set_order_status
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

  def get_items_count
    count = 0
    return count if self.order_items.empty?
    self.order_items.each do |item|
      count = count + item.qty unless item.qty.nil?
    end
    count
  end

  def update_inventory_levels_for_items
    changed_hash = self.saved_changes
    #TODO: remove this from here as soon as possible.
    # Very slow way to ensure inventory always gets allocated
    Groovepacker::Inventory::Orders.allocate(self)

    return true if changed_hash['status'].nil?

    initial_status = changed_hash['status'][0]
    final_status = changed_hash['status'][1]
    if ALLOCATE_STATUSES.include?(initial_status)
      if UNALLOCATE_STATUSES.include?(final_status)
        # Allocate -> unallocate = deallocate inv
        Groovepacker::Inventory::Orders.deallocate(self, true)
      elsif SOLD_STATUSES.include?(final_status)
        # Allocate -> sold = sell inventory
        Groovepacker::Inventory::Orders.sell(self)
      end
    elsif UNALLOCATE_STATUSES.include?(initial_status)
      # Unallocate -> allocate = Allocate inventory
      Groovepacker::Inventory::Orders.allocate(self, true) if ALLOCATE_STATUSES.include?(final_status)
    elsif SOLD_STATUSES.include?(initial_status)
      if ALLOCATE_STATUSES.include?(final_status)
        Groovepacker::Inventory::Orders.unsell(self)
        if self.order_items.select { |o| o.product.is_intangible == false }.count ==  self.order_items.where(scanned_status: "scanned").select { |o| o.product.is_intangible == false }.count
          user = User.find_by_id(GroovRealtime.current_user_id)
          self.reset_scanned_status(user)
        end  
      end
    end
    self.update_column(:reallocate_inventory, false)
    true
  end

  def perform_pre_save_checks
    self.non_hyphen_increment_id = non_hyphenated_string(self.increment_id.to_s).squish
    self.increment_id = self.increment_id.to_s.squish!
    if self.status.nil?
      self.status = 'onhold'
    end
  end

  def scanned_items_count
    count = 0
    self.order_items.each do |item|
      if item.try(:product).try(:is_kit) == 1
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
        count += item.scanned_qty
      end
    end
    count
  end

  def clicked_items_count
    count = 0
    self.order_items.each do |item|
      if item.product.is_kit == 1
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
        count += item.clicked_qty
      end
    end
    count
  end

  def unacknowledged_activities
    order_activities.where('activity_type in (:types)', types: 'deleted_item').where(acknowledged: false)
  end

  def add_item_to_order(product)
    order_item = OrderItem.new
    order_item.product = product
    order_item.name = product.name
    unless product.product_skus.empty?
      order_item.sku = product.product_skus.first.sku
    end
    order_item.qty = 1
    order_item.order = self
    order_item.save
    self.update_order_status
  end

  def destroy_exceptions(result, current_user, tenant)
    if order_exception.destroy
      addactivity("Order Exception Cleared", current_user.name)
      stat_stream_obj = SendStatStream.new()
      stat_stream_obj.delay(:run_at => 1.seconds.from_now, :queue => 'clear_order_exception_#{self.id}').send_order_exception(self.id, tenant)
    else
      result['status'] &= false
      result['messages'].push('Error clearing exceptions')
    end
    result
  end

  def set_traced_in_dashboard
    self.traced_in_dashboard = true
    self.save!
  end

  def partially_load_order_item(order_item_status, limit, offset)
    # if order_item_status == ["scanned", "partially_scanned"]
    #   order_items.where(scanned_status: order_item_status).order('updated_at desc').offset(offset)
    # else
    #   order_items.where(scanned_status: order_item_status).limit(limit).offset(offset)
    # end
    all_order_items = order_items.where(scanned_status: order_item_status)
    order_item_status == %w(scanned partially_scanned) ? all_order_items.order('updated_at desc').offset(offset) : all_order_items.limit(limit).offset(offset)
  end

  def order_items_with_eger_load_and_cache(order_item_status, limit, offset)
    # key = "order_items_#{id}_was_egar_loaded"
    limited_order_items = partially_load_order_item(order_item_status, limit, offset)
    if !( %w(lairdsuperfood).include?(Apartment::Tenant.current)) && (limited_order_items.map(&:keys?).include? true)
      limited_order_items
    else
      # Rails.cache.write(key, true, expires_in: 30.minutes)
      limited_order_items.includes(
        order_item_kit_products: [
          product_kit_skus: [
            product: %i(product_skus product_images product_barcodes)
          ]
        ],
        product: %i(product_skus product_images product_barcodes)
      )
    end
  rescue
    delete_cached_order_items_keys
    retry
  end

  def delete_cached_order_items_keys
    order_items.map(&:delete_cache)
  end

  def delete_if_order_exist
    orders = Order.where(increment_id: increment_id)
    self.destroy if orders.count > 1
  end

  def unique_order_items
    self.order_items = self.order_items.uniq_by {|obj| obj.product_id} 
  end

  def destroy_boxes
    Box.where(order_id: self.id).destroy_all
  end
end
