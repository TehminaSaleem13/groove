class OrderItemKitProduct < ActiveRecord::Base
  belongs_to :order_item
  belongs_to :product_kit_skus
  has_many :order_item_kit_product_scan_times
  attr_accessible :scanned_qty, :scanned_status

  include OrdersHelper
  #===========================================================================================
  #please update the delete_orders library if adding before_destroy or after_destroy callback
  # or adding dependent destroy for associated models
  #===========================================================================================
  SCANNED_STATUS = 'scanned'
  UNSCANNED_STATUS = 'unscanned'
  PARTIALLY_SCANNED_STATUS = 'partially_scanned'

  def process_item(clicked, username, typein_count=1)
    # order_item_unscanned = false
    # order_unscanned = false
    total_qty = calculate_total_item
    # if self.order_item.product.kit_parsing == 'depends'
    #   total_qty = self.order_item.kit_split_qty
    # else
    #   total_qty = self.order_item.qty
    # end
    total_product_kit_skus = total_qty * self.product_kit_skus.qty
    if self.scanned_qty < total_product_kit_skus
      self.scanned_qty += typein_count
      set_clicked_qty(clicked, username, typein_count)
      # if clicked
      #   self.clicked_qty = self.clicked_qty + typein_count
      #   self.order_item.order.addactivity("Item with SKU: " +
      #                                       self.product_kit_skus.option_product.primary_sku + " has been click scanned", username)
      # end
      set_scanned_status(total_product_kit_skus)
      # if self.scanned_qty == total_product_kit_skus
      #   self.scanned_status = SCANNED_STATUS
      # else
      #   self.scanned_status = PARTIALLY_SCANNED_STATUS
      # end
      self.save
      calculate_scan_time(typein_count, username)
      # scan_time = self.order_item_kit_product_scan_times.create(
      #   scan_start: self.order_item.order.last_suggested_at,
      #   scan_end: DateTime.now)
      # if typein_count > 0
      #   avg_time = avg_time_per_item(username)
      #   if avg_time
      #     self.order_item.order.total_scan_time += (avg_time * typein_count).to_i
      #   else
      #     self.order_item.order.total_scan_time += (scan_time.scan_end - scan_time.scan_start).to_i * typein_count
      #   end
      # else
      #   self.order_item.order.total_scan_time = self.order_item.order.total_scan_time +
      #     (scan_time.scan_end - scan_time.scan_start).to_i
      # end
      self.order_item.order.total_scan_count += 1
      self.order_item.order.save

      #need to update order item quantity,
      # for this calculate minimum of order items
      #update order item status
      min = set_min_value
      # product_kit_skus_qty = self.order_item.order_item_kit_products.first.product_kit_skus.qty
      # if product_kit_skus_qty != 0
      #   min = self.order_item.order_item_kit_products.first.scanned_qty /
      #     product_kit_skus_qty
      # else
      #   min = 0
      # end
      # if self.order_item.order_item_kit_products.first.product_kit_skus.qty != 0
      #   min = self.order_item.order_item_kit_products.first.scanned_qty /
      #     self.order_item.order_item_kit_products.first.product_kit_skus.qty
      # else
      #   min = 0
      # end

      # self.order_item.order_item_kit_products.each do |kit_product|
      #   temp = kit_product.scanned_qty / kit_product.product_kit_skus.qty
      #   min = temp if (temp) < min
      # end

      set_order_item_scanned_qty(min)

      # if self.order_item.product.kit_parsing == 'depends'
      #   self.order_item.kit_split_scanned_qty = min
      #   self.order_item.scanned_qty = self.order_item.single_scanned_qty +
      #     self.order_item.kit_split_scanned_qty
      # else
      #   self.order_item.scanned_qty = min
      # end

      set_order_item_scanned_statys

      # if self.order_item.scanned_qty != self.order_item.qty
      #   self.order_item.scanned_status = PARTIALLY_SCANNED_STATUS
      # else
      #   self.order_item.scanned_status = SCANNED_STATUS
      # end
      self.order_item.save

      #update order status
      # self.order_item.order.order_items.each do |order_item|
      #   if order_item.scanned_status != SCANNED_STATUS
      #     order_unscanned = true
      #   end
      # end
      # if order_unscanned
      #   self.order_item.order.status = 'awaiting'
      # else
      #       self.order_item.order.set_order_to_scanned_state
      # end
      # self.order_item.order.save
    end
  end

  def reset_scanned
    self.scanned_status = UNSCANNED_STATUS
    self.scanned_qty = 0
    self.save
  end

  private

  def calculate_total_item
    if self.order_item.product.kit_parsing == 'depends'
      self.order_item.kit_split_qty
    else
      self.order_item.qty
    end
  end

  def set_clicked_qty(clicked, username, typein_count)
    if clicked
      self.clicked_qty = self.clicked_qty + typein_count
      self.order_item.order.addactivity("Item with SKU: " +
                                          self.product_kit_skus.option_product.primary_sku + " has been click scanned", username)
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
    scan_time = self.order_item_kit_product_scan_times.create(
      scan_start: self.order_item.order.last_suggested_at,
      scan_end: DateTime.now)
    total_scan_time_for_order = self.order_item.order.total_scan_time
    scan_duration_per_item = (scan_time.scan_end - scan_time.scan_start).to_i
    if typein_count > 0
      avg_time = avg_time_per_item(username)
      if avg_time
        total_scan_time_for_order += (avg_time * typein_count).to_i
      else
        total_scan_time_for_order += scan_duration_per_item * typein_count
      end
    else
      total_scan_time_for_order += scan_duration_per_item
    end
    self.order_item.order.total_scan_time = total_scan_time_for_order
  end

  def set_min_value
    product_kit_skus_qty = self.order_item.order_item_kit_products.first.product_kit_skus.qty
    min = 0
    min = self.order_item.order_item_kit_products.first.scanned_qty / product_kit_skus_qty if product_kit_skus_qty != 0
    self.order_item.order_item_kit_products.each do |kit_product|
      temp = kit_product.scanned_qty / kit_product.product_kit_skus.qty
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
