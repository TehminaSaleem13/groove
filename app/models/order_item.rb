class OrderItem < ActiveRecord::Base
  belongs_to :order
  belongs_to :product

  has_many :order_item_kit_products, :dependent => :destroy
  has_many :order_item_order_serial_product_lots
  has_many :order_item_scan_times, :dependent => :destroy
  has_one :product_barcode
  has_one :product_sku
  attr_accessible :price, :qty, :row_total, :sku, :product, :product_is_deleted, :name, :product_id,
                  :cached_methods
  #===========================================================================================
  #please update the delete_orders library if adding before_destroy or after_destroy callback
  # or adding dependent destroy for associated models
  #===========================================================================================
  after_create :add_kit_products
  before_destroy :delete_inventory
  after_create :create_inventory
  after_update :update_inventory_levels
  after_save :delete_cache

  include OrdersHelper

  # Move to enum when possible
  # :inv_status
  DEFAULT_INV_STATUS = 'unprocessed'
  ALLOCATED_INV_STATUS = 'allocated'
  UNALLOCATED_INV_STATUS = 'unallocated'
  SOLD_INV_STATUS = 'sold'

  #:scanned_status
  SCANNED_STATUS = 'scanned'
  UNSCANNED_STATUS = 'unscanned'
  PARTIALLY_SCANNED_STATUS = 'partially_scanned'

  include CachedMethods
  cached_methods :product, :order_item_kit_products

  def has_unscanned_kit_items
    result = false
    self.order_item_kit_products.each do |kit_product|
      if kit_product.scanned_status != SCANNED_STATUS
        result = true
        break
      end
    end
    result
  end

  def is_not_ghost?
    !self.order.nil? && !self.product.nil? && self.order.has_store_and_warehouse?
  end

  def is_inventory_allocated?
    self.inv_status == ALLOCATED_INV_STATUS
  end

  def is_inventory_unallocated?
    self.inv_status == UNALLOCATED_INV_STATUS
  end

  def is_inventory_unprocessed?
    self.inv_status == DEFAULT_INV_STATUS
  end

  def is_inventory_sold?
    self.inv_status == SOLD_INV_STATUS
  end


  def has_atleast_one_item_scanned
    result = false
    self.order_item_kit_products.each do |kit_product|
      if kit_product.scanned_status != UNSCANNED_STATUS
        result = true
        break
      end
    end
    result
  end

  def build_basic_item(item)
    result = Hash.new
    result['name'] = item.name
    sort_by_order = Proc.new do |collection|
      collection.sort{|a,b| a.order <=> b.order}
    end
    result['instruction'] = item.spl_instructions_4_packer
    result['confirmation'] = item.spl_instructions_4_confirmation
    result['images'] = sort_by_order[item.cached_product_images]
    result['sku'] = sort_by_order[item.cached_product_skus].first.sku if item.cached_product_skus.length > 0
    result['packing_placement'] = item.packing_placement
    result['barcodes'] = sort_by_order[item.cached_product_barcodes]
    result['product_id'] = item.id
    result['skippable'] = item.is_skippable
    result['record_serial'] = item.record_serial
    result['click_scan_enabled'] = item.click_scan_enabled
    result['type_scan_enabled'] = item.type_scan_enabled
    result['order_item_id'] = self.id

    result
  end

  def build_single_item(depends_kit)
    result = Hash.new
    if !self.cached_product.nil?
      result = self.build_basic_item(self.cached_product)
      result['product_type'] = 'single'
      if depends_kit
        result['qty_remaining'] =
          (self.qty - self.kit_split_qty) - (self.scanned_qty-self.kit_split_scanned_qty)
      else
        result['qty_remaining'] =
          self.qty - self.scanned_qty
      end
    end
    result
  end

  def build_single_child_item(kit_product, depends_kit, option_products_array)
    child_item = {}
    option_product = find_option_product(option_products_array, kit_product)
    child_item = build_basic_item(option_product)
    #overwrite scanned qty from basic build
    child_item['scanned_qty'] = kit_product.scanned_qty

    if depends_kit
      child_item['qty_remaining'] = self.kit_split_qty * kit_product.product_kit_skus.qty -
        kit_product.scanned_qty
    else
      child_item['qty_remaining'] = self.qty * kit_product.product_kit_skus.qty -
        kit_product.scanned_qty
    end

    child_item['kit_packing_placement'] = kit_product.product_kit_skus.packing_order
    child_item['kit_product_id'] = kit_product.id
    child_item
  end

  def option_products
    option_product_ids = cached_order_item_kit_products
      .map(&:cached_product_kit_skus).flatten.compact.map(&:option_product_id)
    Product.where(id: option_product_ids)
  end

  def build_individual_kit(depends_kit)
    result = Hash.new
    result = build_basic_item(self.product)
    result['product_type'] = 'individual'
    if depends_kit
      result['qty_remaining'] = self.kit_split_qty - self.kit_split_scanned_qty
    else
      result['qty_remaining'] = self.qty - self.scanned_qty
    end
    result['scanned_qty'] = self.scanned_qty
    result['child_items'] = []
    result
  end

  def build_unscanned_single_item(depends_kit = false)
    result = Hash.new
    unless self.cached_product.nil?
      result = self.build_single_item(depends_kit)
      result['scanned_qty'] = self.scanned_qty
    end
    result
  end

  def build_unscanned_individual_kit (option_products_array, depends_kit = false)
    result = {}
    unless self.product.nil?
      result = self.build_individual_kit(depends_kit)
      self.cached_order_item_kit_products.each do |kit_product|
        if !kit_product.product_kit_skus.nil? &&
          !kit_product.product_kit_skus.product.nil? &&
          kit_product.scanned_status != 'scanned'
          child_item = self.build_single_child_item(kit_product, depends_kit, option_products_array)

          result['child_items'].push(child_item) if child_item['qty_remaining'] != 0
        end
      end
      result['child_items'] = result['child_items'].sort_by { |hsh| hsh['kit_packing_placement'] }
    end
    result
  end

  def build_scanned_single_item(depends_kit = false)
    result = Hash.new
    unless self.product.nil?
      result = self.build_single_item(depends_kit)
      if depends_kit
        result['scanned_qty'] = self.single_scanned_qty
      else
        result['scanned_qty'] = self.scanned_qty
      end
    end
    result
  end

  def build_scanned_individual_kit(option_products_array, depends_kit = false)
    result = Hash.new
    if !self.product.nil?
      result = self.build_individual_kit(depends_kit)
      if depends_kit
        result['scanned_qty'] = self.kit_split_scanned_qty
      end
      self.order_item_kit_products.each do |kit_product|
        if !kit_product.product_kit_skus.nil? &&
          !kit_product.product_kit_skus.product.nil? &&
          (kit_product.scanned_status == SCANNED_STATUS or
            kit_product.scanned_status == PARTIALLY_SCANNED_STATUS)
          child_item = self.build_single_child_item(kit_product, depends_kit, option_products_array)
          result['child_items'].push(child_item) if child_item['scanned_qty'] != 0
        end
      end
    end
    result
  end


  def process_item(clicked, username, typein_count=1)
    order_unscanned = false

    if self.scanned_qty < self.qty
      total_qty = 0
      if self.product.kit_parsing == 'depends'
        self.single_scanned_qty = self.single_scanned_qty + typein_count
        set_clicked_quantity(clicked, self.product.primary_sku, username)
        self.scanned_qty = self.single_scanned_qty + self.kit_split_scanned_qty
        total_qty = self.qty - self.kit_split_qty
      else
        self.scanned_qty = self.scanned_qty + typein_count
        set_clicked_quantity(clicked, self.product.primary_sku, username)
        total_qty = self.qty - self.kit_split_qty
      end
      scan_time = self.order_item_scan_times.create(
        scan_start: self.order.last_suggested_at,
        scan_end: DateTime.now)
      if typein_count > 1
        avg_time = avg_time_per_item(username)
        if avg_time
          self.order.total_scan_time += (avg_time * typein_count).to_i
        else
          self.order.total_scan_time += (scan_time.scan_end - scan_time.scan_start).to_i * typein_count
        end
      else
        self.order.total_scan_time = self.order.total_scan_time +
          (scan_time.scan_end - scan_time.scan_start).to_i
      end
      self.order.total_scan_count = self.order.total_scan_count + typein_count
      self.order.save
      if self.scanned_qty == self.qty
        self.scanned_status = SCANNED_STATUS
      else
        self.scanned_status = PARTIALLY_SCANNED_STATUS
      end
      self.save
    end

  end

  def should_kit_split_qty_be_increased(product_id)
    result = false
    if self.product.is_kit == 1 && self.kit_split &&
      self.product.kit_parsing == 'depends'

      #if no of unscanned items in the kit split qty for the corrseponding item
      #is greater than 0 and the kit split can be increased in the order item,
      #then the quantity should be increased
      self.order_item_kit_products.each do |kit_product|
        if kit_product.product_kit_skus.option_product.id == product_id &&
          kit_product.scanned_qty != 0 &&
          (kit_product.scanned_qty % (self.kit_split_qty * kit_product.product_kit_skus.qty) == 0) &&
          self.scanned_qty < self.qty
          result = true
        end
      end
    end

    result
  end

  def remove_order_item_kit_products
    result = true
    unless self.product.nil?
      if self.product.is_kit == 1
        self.order_item_kit_products.each do |kit_product|
          kit_product.destroy
        end
      end
    end
    result
  end

  def reset_scanned
    #if item is a kit then make all order item product skus as also unscanned
    if self.product.is_kit == 1
      self.order_item_kit_products.each do |kit_product|
        kit_product.reset_scanned
      end
    end

    self.scanned_status = UNSCANNED_STATUS
    self.scanned_qty = 0
    self.kit_split = false
    self.kit_split_qty = 0
    self.kit_split_scanned_qty = 0
    self.single_scanned_qty = 0
    self.save
  end

  def delete_inventory
    Groovepacker::Inventory::Orders::deallocate_item(self)
    #send true regardless to avoid ghost data.
    true
  end

  def create_inventory
    Groovepacker::Inventory::Orders::allocate_item(self)
    true
  end

  def update_inventory_levels
    result = true
    changed_hash = self.changes
    if !changed_hash.nil? and (!changed_hash['qty'].nil?)
      result &= Groovepacker::Inventory::Orders.item_update(self, changed_hash['qty'][0], changed_hash['qty'][1])
    end
    result
  end

  def add_kit_products
    if !self.product.nil? && self.product.is_kit == 1
      self.product.product_kit_skuss.each do |kit_sku|
        kit_sku.add_product_in_order_items
      end
    end

  end

  # def get_base_product
  #   if self.is_incremental_item
  #     return self.product.base_product
  #   else
  #     return self.product
  #   end
  # end

  def get_lot_number
    unless self.product_lots.empty?
      return self.product_lots
    else
      return []
    end
  end

  def get_barcode_with_lotnumber(barcode, lot_number)
    scanpack_settings = ScanPackSetting.all.first
    unless scanpack_settings.escape_string.nil?
      return barcode + scanpack_settings.escape_string + lot_number
    end
  end

  private

  def set_clicked_quantity(clicked, sku, username)
    if clicked
      self.clicked_qty = self.clicked_qty + 1
      self.order.addactivity("Item with SKU: " +
                               sku + " has been click scanned", username)
    end
  end

  def find_option_product(option_products_array, kit_product)
    option_products_array
      .find { |op| op.id == kit_product.cached_product_kit_skus.option_product_id }
  end

end
