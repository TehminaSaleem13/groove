# frozen_string_literal: true

class OrderItem < ApplicationRecord
  belongs_to :order, optional: true
  belongs_to :product, optional: true
  has_many :order_item_boxes, dependent: :destroy
  has_many :boxes, through: :order_item_boxes

  has_many :order_item_kit_products, dependent: :destroy
  has_many :order_item_order_serial_product_lots
  has_many :order_item_scan_times, dependent: :destroy
  has_one :product_barcode
  has_one :product_sku
  # attr_accessible :price, :qty, :row_total, :sku, :product, :product_is_deleted, :name, :product_id,
  #                 :cached_methods, :box_id, :skipped_qty, :scanned_status
  #===========================================================================================
  # please update the delete_orders library if adding before_destroy or after_destroy callback
  # or adding dependent destroy for associated models
  #===========================================================================================
  before_save :update_product_name
  after_create :add_kit_products
  before_destroy :delete_inventory
  after_create :create_inventory
  after_update :update_inventory_levels
  # validates_uniqueness_of :sku, scope: :order_id
  cached_methods :product, :order_item_kit_products, :option_products
  after_save :delete_cache_for_associated_obj

  attr_accessor :scan_pack_v2

  include OrdersHelper

  # Move to enum when possible
  # :inv_status
  DEFAULT_INV_STATUS = 'unprocessed'
  ALLOCATED_INV_STATUS = 'allocated'
  UNALLOCATED_INV_STATUS = 'unallocated'
  SOLD_INV_STATUS = 'sold'

  # :scanned_status
  SCANNED_STATUS = 'scanned'
  UNSCANNED_STATUS = 'unscanned'
  PARTIALLY_SCANNED_STATUS = 'partially_scanned'

  QTY_OF_SKU = 'Qty 1 of SKU: '

  scope :not_scanned, -> { where.not(scanned_status: SCANNED_STATUS) }

  def has_unscanned_kit_items
    result = false
    order_item_kit_products.each do |kit_product|
      next if kit_product.cached_product_kit_skus.option_product.try(:is_intangible)

      if kit_product.scanned_status != SCANNED_STATUS
        result = true
        break
      end
    end
    result
  end

  def is_not_ghost?
    !order.nil? && !product.nil? && order.has_store_and_warehouse?
  end

  def is_inventory_allocated?
    inv_status == ALLOCATED_INV_STATUS
  end

  def is_inventory_unallocated?
    inv_status == UNALLOCATED_INV_STATUS
  end

  def is_inventory_unprocessed?
    inv_status == DEFAULT_INV_STATUS
  end

  def is_inventory_sold?
    inv_status == SOLD_INV_STATUS
  end

  def has_atleast_one_item_scanned
    result = false
    order_item_kit_products.each do |kit_product|
      if kit_product.scanned_status != UNSCANNED_STATUS
        result = true
        break
      end
    end
    result
  end

  def build_basic_item(item)
    result = {}
    result['name'] = item.name
    sort_by_order = proc do |collection|
      collection.sort_by(&:order)
    rescue StandardError
      puts '*******************************'
      puts collection
      puts '###############################'
      collection
    end
    result['instruction'] = item.packing_instructions
    result['confirmation'] = item.packing_instructions_conf
    result['images'] = sort_by_order[item.cached_product_images]
    cached_item_product_skus = item.cached_product_skus
    result['sku'] = sort_by_order[cached_item_product_skus].first.sku unless cached_item_product_skus.empty?
    result['packing_placement'] = item.packing_placement
    result['barcodes'] = sort_by_order[item.cached_product_barcodes]
    result['product_id'] = item.id
    product_inv_warehouses = begin
      item.product_inventory_warehousess[0]
    rescue StandardError
      nil
    end
    result['location'] = product_inv_warehouses.try(:location_primary)
    result['location2'] = product_inv_warehouses.try(:location_secondary)
    result['location3'] = product_inv_warehouses.try(:location_tertiary)
    result['skippable'] = item.is_skippable
    result['record_serial'] = item.record_serial
    result['second_record_serial'] = item.second_record_serial
    result['click_scan_enabled'] = item.click_scan_enabled
    result['type_scan_enabled'] = item.type_scan_enabled
    result['order_item_id'] = id
    result['box_id'] = box_id
    result['custom_product_1'] = item.custom_product_1
    result['custom_product_2'] = item.custom_product_2
    result['custom_product_3'] = item.custom_product_3
    result['custom_product_display_1'] = item.custom_product_display_1
    result['custom_product_display_2'] = item.custom_product_display_2
    result['custom_product_display_3'] = item.custom_product_display_3
    result['partially_scanned'] = false
    result['partially_scanned'] = true if scanned_status == 'partially_scanned' && cached_order_item_kit_products.any?
    result['updated_at'] = updated_at
    result
  end

  def build_single_item(depends_kit)
    result = {}
    unless cached_product.nil?
      result = build_basic_item(cached_product)
      result['product_type'] = 'single'
      result['qty_remaining'] = if depends_kit
                                  (qty - kit_split_qty) - (scanned_qty - kit_split_scanned_qty)
                                else
                                  qty - scanned_qty
                                end
      result['total_qty'] = qty
    end
    result
  end

  def build_single_child_item(kit_product, depends_kit, option_products_array)
    child_item = {}
    option_product = find_option_product(option_products_array, kit_product)
    child_item = build_basic_item(option_product)
    kit_product.cached_product_kit_skus.reload
    # overwrite scanned qty from basic build
    child_item['scanned_qty'] = kit_product.scanned_qty
    child_item['qty_remaining'] = if depends_kit
                                    kit_split_qty * kit_product.cached_product_kit_skus.qty -
                                      kit_product.scanned_qty
                                  else
                                    qty * kit_product.cached_product_kit_skus.qty -
                                      kit_product.scanned_qty
                                  end
    child_item['total_qty'] = qty
    child_item['kit_packing_placement'] = kit_product.cached_product_kit_skus.packing_order
    child_item['kit_product_id'] = kit_product.id
    child_item['updated_at'] = updated_at
    child_item['product_qty_in_kit'] = kit_product.cached_product_kit_skus.qty
    child_item
  end

  def option_products
    product_ids = cached_order_item_kit_products
                  .map(&:cached_product_kit_skus).flatten.compact
                  .map(&:cached_option_product)
  end

  def build_individual_kit(depends_kit)
    result = {}
    result = build_basic_item(product)
    result['product_type'] = scan_pack_v2 ? 'depends' : 'individual'
    result['qty_remaining'] = if depends_kit
                                kit_split_qty - kit_split_scanned_qty
                              else
                                qty - scanned_qty
                              end
    result['scanned_qty'] = scanned_qty
    result['total_qty'] = qty
    result['child_items'] = []
    result
  end

  def build_unscanned_single_item(depends_kit = false)
    result = {}
    unless cached_product.nil?
      result = build_single_item(depends_kit)
      result['scanned_qty'] = scanned_qty
    end
    result
  end

  def build_unscanned_individual_kit(option_products_array, depends_kit = false)
    result = {}
    unless cached_product.nil?
      result = build_individual_kit(depends_kit)
      cached_order_item_kit_products.each do |kit_product|
        next unless !kit_product.cached_product_kit_skus.nil? &&
                    !kit_product.cached_product_kit_skus.product.nil? &&
                    !kit_product.cached_product_kit_skus.option_product.is_intangible &&
                    kit_product.scanned_status != 'scanned'

        child_item = build_single_child_item(kit_product, depends_kit, option_products_array)

        result['child_items'].push(child_item) if child_item['qty_remaining'] != 0
      end
      result['child_items'] = result['child_items'].sort_by { |hsh| hsh['kit_packing_placement'] }
    end
    result
  end

  def build_scanned_single_item(depends_kit = false)
    result = {}
    unless product.nil?
      result = build_single_item(depends_kit)
      result['scanned_qty'] = if depends_kit
                                single_scanned_qty
                              else
                                scanned_qty
                              end
    end
    result
  end

  def build_scanned_individual_kit(option_products_array, depends_kit = false)
    result = {}
    unless product.nil?
      result = build_individual_kit(depends_kit)
      result['scanned_qty'] = kit_split_scanned_qty if depends_kit
      cached_order_item_kit_products.each do |kit_product|
        next unless !kit_product.cached_product_kit_skus.nil? &&
                    !kit_product.cached_product_kit_skus.product.nil? &&
                    ((kit_product.scanned_status == SCANNED_STATUS) ||
                      (kit_product.scanned_status == PARTIALLY_SCANNED_STATUS))

        child_item = build_single_child_item(kit_product, depends_kit, option_products_array)
        result['child_items'].push(child_item) if child_item['scanned_qty'] != 0
      end
    end
    result
  end

  def process_item(clicked, username, typein_count = 1, box_id, on_ex)
    order_unscanned = false
    return unless scanned_qty < qty

    total_qty = 0
    if product.kit_parsing == 'depends'
      self.single_scanned_qty = single_scanned_qty + typein_count
      set_clicked_quantity(clicked, product.primary_sku, username, box_id, on_ex)
      self.scanned_qty = single_scanned_qty + kit_split_scanned_qty
      total_qty = qty - kit_split_qty
    else
      self.scanned_qty = scanned_qty + typein_count
      set_clicked_quantity(clicked, product.primary_sku, username, box_id, on_ex)
      total_qty = qty - kit_split_qty
    end
    scan_time = order_item_scan_times.build(
      scan_start: order.last_suggested_at, scan_end: DateTime.now.in_time_zone
    )
    scan_time.save
    if typein_count > 1
      avg_time = avg_time_per_item(username)
      order.total_scan_time += if avg_time
                                 (avg_time * typein_count).to_i
                               else
                                 (scan_time.scan_end - scan_time.scan_start).to_i * typein_count
                               end
    else
      order.total_scan_time = order.total_scan_time +
                              (scan_time.scan_end.to_i - scan_time.scan_start.to_i)
    end
    order.total_scan_count = order.total_scan_count + typein_count
    order.save
    self.scanned_status = if scanned_qty == qty
                            SCANNED_STATUS
                          else
                            PARTIALLY_SCANNED_STATUS
                          end
    save
    tenant = Apartment::Tenant.current
    if !Rails.env.test? && Tenant.where(name: tenant).last.groovelytic_stat && order.has_unscanned_items && ExportSetting.first.include_partially_scanned_orders_user_stats
      SendStatStream.new.delay(run_at: 1.second.from_now, queue: 'export_stat_stream_scheduled_' + tenant, priority: 95).build_send_stream(
        tenant, order.id
      )
    end
  end

  def should_kit_split_qty_be_increased(product_id)
    result = false
    if product.is_kit == 1 && kit_split &&
       product.kit_parsing == 'depends'

      # if no of unscanned items in the kit split qty for the corrseponding item
      # is greater than 0 and the kit split can be increased in the order item,
      # then the quantity should be increased
      cached_order_item_kit_products.each do |kit_product|
        next unless kit_product.cached_product_kit_skus.cached_option_product.id == product_id &&
                    kit_product.scanned_qty != 0 &&
                    (kit_product.scanned_qty % (kit_split_qty * kit_product.cached_product_kit_skus.qty) == 0) &&
                    scanned_qty < qty

        result = true
      end
    end

    result
  end

  def remove_order_item_kit_products
    result = true
    order_item_kit_products.each(&:destroy) if !product.nil? && (product.is_kit == 1)
    result
  end

  def reset_scanned
    # if item is a kit then make all order item product skus as also unscanned
    order_item_kit_products.each(&:reset_scanned) if product.is_kit == 1

    self.scanned_status = UNSCANNED_STATUS
    self.scanned_qty = 0
    self.kit_split = false
    self.kit_split_qty = 0
    self.kit_split_scanned_qty = 0
    self.single_scanned_qty = 0
    self.clicked_qty = 0
    self.qty += skipped_qty if skipped_qty > 0
    self.skipped_qty = 0
    save
  end

  def delete_inventory
    Groovepacker::Inventory::Orders.deallocate_item(self)
    # send true regardless to avoid ghost data.
    true
  end

  def create_inventory
    Groovepacker::Inventory::Orders.allocate_item(self)
    true
  end

  def update_inventory_levels
    result = true
    changed_hash = saved_changes
    if !changed_hash.nil? && !changed_hash['qty'].nil?
      result &= Groovepacker::Inventory::Orders.item_update(self, changed_hash['qty'][0], changed_hash['qty'][1])
    end
    result
  end

  def add_kit_products
    product.product_kit_skuss.each(&:add_product_in_order_items) if !product.nil? && product.is_kit == 1
  end

  # def get_base_product
  #   if self.is_incremental_item
  #     return self.product.base_product
  #   else
  #     return self.product
  #   end
  # end

  def get_lot_number
    if product_lots.empty?
      []
    else
      product_lots
    end
  end

  def get_barcode_with_lotnumber(barcode, lot_number)
    scanpack_settings = ScanPackSetting.all.first
    barcode + scanpack_settings.escape_string + lot_number unless scanpack_settings.escape_string.nil?
  end

  def delete_cache_for_associated_obj
    product.try(:delete_cache)
    order_item_kit_products.map(&:delete_cache)
    order_item_kit_products.map(&:product_kit_skus).map(&:delete_cache)
    order_item_kit_products.map(&:product_kit_skus).map(&:option_product).map(&:delete_cache)
    delete_cache
  end

  private

  def set_clicked_quantity(clicked, sku, username, box_id, on_ex)
    return unless clicked

    self.clicked_qty = clicked_qty + 1
    if box_id.blank?
      if GeneralSetting.last.multi_box_shipments?
        unless ScanPackSetting.last.order_verification
          order.addactivity(QTY_OF_SKU + sku.to_s + ' was passed with the Pass option in Box 1', username,
                            on_ex)
        end
      else
        unless ScanPackSetting.last.order_verification
          order.addactivity(QTY_OF_SKU + sku.to_s + ' was passed with the Pass option', username,
                            on_ex)
        end
      end
    else
      box = Box.where(id: box_id).last
      unless ScanPackSetting.last.order_verification
        order.addactivity(QTY_OF_SKU + sku.to_s + " was passed with the Pass option in #{box.try(:name)}", username,
                          on_ex)
      end
    end
  end

  def find_option_product(option_products_array, kit_product)
    option_products_array
      .find { |op| op.id == kit_product.cached_product_kit_skus.option_product_id }
  end

  def update_product_name
    self.name = product&.name.to_s unless name.present?
    self.sku = product&.primary_sku.to_s unless sku.present?
  end
end
