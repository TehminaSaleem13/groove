# frozen_string_literal: true

class OrderItemKitProduct < ActiveRecord::Base
  belongs_to :order_item, touch: true
  belongs_to :product_kit_skus
  has_many :order_item_kit_product_scan_times
  # attr_accessible :scanned_qty, :scanned_status

  cached_methods :product_kit_skus
  after_save :delete_cache

  include OrdersHelper
  #===========================================================================================
  # please update the delete_orders library if adding before_destroy or after_destroy callback
  # or adding dependent destroy for associated models
  #===========================================================================================
  SCANNED_STATUS = 'scanned'
  UNSCANNED_STATUS = 'unscanned'
  PARTIALLY_SCANNED_STATUS = 'partially_scanned'

  def process_item(clicked, username, typein_count = 1, is_skipped = nil, on_ex)
    total_product_kit_skus = calculate_total_product_kit_skus
    return unless scanned_qty < total_product_kit_skus

    self.scanned_qty += is_skipped ? total_product_kit_skus : typein_count
    set_clicked_qty(clicked, username, typein_count, on_ex)
    set_scanned_status(total_product_kit_skus)
    save
    calculate_scan_time(typein_count, username)
    order_item.order.total_scan_count += typein_count
    order_item.order.save

    # need to update order item quantity,
    # for this calculate minimum of order items
    # update order item status
    min = set_min_value
    set_order_item_scanned_qty(min)
    set_order_item_scanned_statys
    order_item.save
  end

  def reset_scanned
    self.scanned_status = UNSCANNED_STATUS
    self.scanned_qty = 0
    save
  end

  private

  def calculate_total_product_kit_skus
    total_qty = 0
    total_qty = if order_item.product.kit_parsing == 'depends'
                  order_item.kit_split_qty
                else
                  order_item.qty
                end
    total_qty * cached_product_kit_skus.qty
  end

  def set_clicked_qty(clicked, username, typein_count, on_ex)
    if clicked
      self.clicked_qty = clicked_qty + typein_count
      order_item.order.addactivity('Kit Part item with SKU: ' + cached_product_kit_skus.cached_option_product.cached_primary_sku + ' has been click scanned', username, on_ex) unless ScanPackSetting.last.order_verification
    end
  end

  def set_scanned_status(total_product_kit_skus)
    self.scanned_status = if self.scanned_qty == total_product_kit_skus
                            SCANNED_STATUS
                          else
                            PARTIALLY_SCANNED_STATUS
                          end
  end

  def calculate_scan_time(typein_count, username)
    scan_time_per_item = calc_scan_time_for_first_item
    total_scan_time_for_order = order_item.order.total_scan_time

    if typein_count > 1
      avg_time = avg_time_per_item(username)
      total_scan_time_for_order += if avg_time
                                     (avg_time * typein_count).to_i
                                   else
                                     scan_time_per_item * typein_count
                                   end
    else
      total_scan_time_for_order += scan_time_per_item
    end
    order_item.order.total_scan_time = total_scan_time_for_order
  end

  def calc_scan_time_for_first_item
    scan_time = order_item_kit_product_scan_times.create(
      scan_start: order_item.order.last_suggested_at,
      scan_end: DateTime.now.in_time_zone
    )
    scan_time.scan_end.to_i - scan_time.scan_start.to_i
  end

  def set_min_value
    order_item_kit_products = order_item.reload.order_item_kit_products
    order_item_kit_product = order_item_kit_products.first
    product_kit_skus_qty = order_item_kit_product.cached_product_kit_skus.qty
    min = 1
    min = order_item_kit_product.scanned_qty / product_kit_skus_qty if product_kit_skus_qty != 0
    order_item_kit_products.each do |kit_product|
      temp = kit_product.scanned_qty / kit_product.cached_product_kit_skus.qty
      min = temp if temp < min
    end
    min
  end

  def set_order_item_scanned_qty(min)
    if order_item.product.kit_parsing == 'depends'
      order_item.kit_split_scanned_qty = min
      order_item.scanned_qty = order_item.single_scanned_qty +
                               order_item.kit_split_scanned_qty
    else
      order_item.scanned_qty = min
    end
  end

  def set_order_item_scanned_statys
    order_item.scanned_status = if order_item.scanned_qty != order_item.qty
                                  PARTIALLY_SCANNED_STATUS
                                else
                                  SCANNED_STATUS
                                     end
  end
end
