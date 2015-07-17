class OrderItemScanTime < ActiveRecord::Base
  attr_accessible :order_item_id, :scan_end, :scan_start
  belongs_to :order_item
end
