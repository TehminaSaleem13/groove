class OrderItemKitProduct < ActiveRecord::Base
  belongs_to :order_item
  belongs_to :product_kit_skus
  has_many :order_item_kit_product_scan_times
  attr_accessible :scanned_qty, :scanned_status

  SCANNED_STATUS = 'scanned'
  UNSCANNED_STATUS = 'unscanned'
  PARTIALLY_SCANNED_STATUS = 'partially_scanned'

  def process_item(clicked, username)
    order_item_unscanned = false
    order_unscanned = false

    if self.order_item.product.kit_parsing == 'depends'
      total_qty = self.order_item.kit_split_qty
    else
      total_qty = self.order_item.qty
    end

    if self.scanned_qty < total_qty * self.product_kit_skus.qty
      self.scanned_qty = self.scanned_qty + 1
      if clicked
        self.clicked_qty = self.clicked_qty + 1
        self.order_item.order.addactivity("Item with SKU: " +
                                            self.product_kit_skus.option_product.primary_sku + " has been click scanned", username)
      end

      if self.scanned_qty == total_qty * self.product_kit_skus.qty
        self.scanned_status = SCANNED_STATUS
      else
        self.scanned_status = PARTIALLY_SCANNED_STATUS
      end
      self.save

      scan_time = self.order_item_kit_product_scan_times.create(
        scan_start: self.order_item.order.last_suggested_at,
        scan_end: DateTime.now)

      self.order_item.order.total_scan_time = self.order_item.order.total_scan_time +
        (scan_time.scan_end - scan_time.scan_start).to_i
      self.order_item.order.total_scan_count = self.order_item.order.total_scan_count + 1
      self.order_item.order.save

      #need to update order item quantity,
      # for this calculate minimum of order items
      #update order item status
      if self.order_item.order_item_kit_products.first.product_kit_skus.qty != 0
        min = self.order_item.order_item_kit_products.first.scanned_qty /
          self.order_item.order_item_kit_products.first.product_kit_skus.qty
      else
        min = 0
      end

      self.order_item.order_item_kit_products.each do |kit_product|
        if (kit_product.scanned_qty / kit_product.product_kit_skus.qty) < min
          min = kit_product.scanned_qty / kit_product.product_kit_skus.qty
        end
      end

      if self.order_item.product.kit_parsing == 'depends'
        self.order_item.kit_split_scanned_qty = min
        self.order_item.scanned_qty = self.order_item.single_scanned_qty +
          self.order_item.kit_split_scanned_qty
      else
        self.order_item.scanned_qty = min
      end

      if self.order_item.scanned_qty != self.order_item.qty
        self.order_item.scanned_status = PARTIALLY_SCANNED_STATUS
      else
        self.order_item.scanned_status = SCANNED_STATUS
      end
      self.order_item.save

      #update order status
      # self.order_item.order.order_items.each do |order_item|
      # 	if order_item.scanned_status != SCANNED_STATUS
      # 		order_unscanned = true
      # 	end
      # end
      # if order_unscanned
      # 	self.order_item.order.status = 'awaiting'
      # else
      #     	self.order_item.order.set_order_to_scanned_state
      # end
      # self.order_item.order.save
    end
  end

  def reset_scanned
    self.scanned_status = UNSCANNED_STATUS
    self.scanned_qty = 0
    self.save
  end
end
