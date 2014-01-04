class OrderItem < ActiveRecord::Base
  belongs_to :order
  belongs_to :product
  attr_accessible :price, :qty, :row_total, :sku

  def has_unscanned_kit_items
  	result = false
  	self.order_item_kit_products.each do |kit_product|
		if kit_product.scanned_status != 'scanned'
			result = true
			break
		end		
  	end
  	result
  end

  def has_atleast_one_item_scanned
  	result = false
  	self.order_item_kit_products.each do |kit_product|
		if kit_product.scanned_status != 'unscanned'
			result = true
			break
		end		
  	end
  	result
  end
end
