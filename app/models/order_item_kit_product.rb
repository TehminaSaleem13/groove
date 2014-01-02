class OrderItemKitProduct < ActiveRecord::Base
  belongs_to :order_item
  belongs_to :product_kit_skus
  attr_accessible :scanned_qty, :scanned_status
end
