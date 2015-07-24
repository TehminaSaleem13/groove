class OrderItemKitProductScanTime < ActiveRecord::Base
  attr_accessible :order_item_kit_product_id, :scan_end, :scan_start
  belongs_to :order_item_kit_product
end
