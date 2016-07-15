class OrderItemKitProduct < ActiveRecord::Base
  belongs_to :order_item
  belongs_to :product_kit_skus
  has_many :order_item_kit_product_scan_times
  attr_accessible :scanned_qty, :scanned_status

  cached_methods :product_kit_skus
  after_save :delete_cache

  include OrdersHelper
  #===========================================================================================
  #please update the delete_orders library if adding before_destroy or after_destroy callback
  # or adding dependent destroy for associated models
  #===========================================================================================
  SCANNED_STATUS = 'scanned'
  UNSCANNED_STATUS = 'unscanned'
  PARTIALLY_SCANNED_STATUS = 'partially_scanned'

  def process_item(clicked, username, typein_count=1)
    total_product_kit_skus = calculate_total_product_kit_skus
    return unless scanned_qty < total_product_kit_skus

    self.scanned_qty += typein_count
    set_clicked_qty(clicked, username, typein_count)
    set_scanned_status(total_product_kit_skus)
    self.save
    calculate_scan_time(typein_count, username)
    self.order_item.order.total_scan_count += typein_count
    self.order_item.order.save

    #need to update order item quantity,
    # for this calculate minimum of order items
    #update order item status
    min = set_min_value
    set_order_item_scanned_qty(min)
    set_order_item_scanned_statys
    self.order_item.save
  end

  def reset_scanned
    self.scanned_status = UNSCANNED_STATUS
    self.scanned_qty = 0
    self.save
  end

  private

  def calculate_total_product_kit_skus
    total_qty = 0
    if self.order_item.product.kit_parsing == 'depends'
      total_qty = self.order_item.kit_split_qty
    else
      total_qty = self.order_item.qty
    end
    total_qty * self.cached_product_kit_skus.qty
  end

  def set_clicked_qty(clicked, username, typein_count)
    if clicked
      self.clicked_qty = self.clicked_qty + typein_count
      self.order_item.order.addactivity("Kit Part item with SKU: " +
                                          self.cached_product_kit_skus.cached_option_product.cached_primary_sku + " has been click scanned", username)
    end
  end

  def set_scanned_status(total_product_kit_skus)
    if self.scanned_qty == total_product_kit_skus
      self.scanned_status = SCANNED_STATUS
    else
      self.scanned_status = PARTIALLY_SCANNED_STATUS
    end
  end

  def calculate_scan_time(typein_count, username)
    scan_time_per_item = calc_scan_time_for_first_item
    total_scan_time_for_order = self.order_item.order.total_scan_time

    if typein_count > 1
      avg_time = avg_time_per_item(username)
      if avg_time
        total_scan_time_for_order += (avg_time * typein_count).to_i
      else
        total_scan_time_for_order += scan_time_per_item * typein_count
      end
    else
      total_scan_time_for_order += scan_time_per_item
    end
    self.order_item.order.total_scan_time = total_scan_time_for_order
  end

  def calc_scan_time_for_first_item
    scan_time = self.order_item_kit_product_scan_times.create(
      scan_start: self.order_item.order.last_suggested_at,
      scan_end: DateTime.now)
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
      min = temp if (temp) < min
    end
    min
  end

  def set_order_item_scanned_qty(min)
    if self.order_item.product.kit_parsing == 'depends'
      self.order_item.kit_split_scanned_qty = min
      self.order_item.scanned_qty = self.order_item.single_scanned_qty +
        self.order_item.kit_split_scanned_qty
    else
      self.order_item.scanned_qty = min
    end
  end

  def set_order_item_scanned_statys
    if self.order_item.scanned_qty != self.order_item.qty
      self.order_item.scanned_status = PARTIALLY_SCANNED_STATUS
    else
      self.order_item.scanned_status = SCANNED_STATUS
    end
  end

end
