class OrderItemKitProductScanTime < ActiveRecord::Base
  attr_accessible :order_item_kit_product_id, :scan_end, :scan_start
  belongs_to :order_item_kit_product
  #===========================================================================================
  #please update the delete_orders library if adding before_destroy or after_destroy callback
  # or adding dependent destroy for associated models
  #===========================================================================================
end
