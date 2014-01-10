class OrderItemKitProduct < ActiveRecord::Base
  belongs_to :order_item
  belongs_to :product_kit_skus
  attr_accessible :scanned_qty, :scanned_status

  def process_item
  	order_item_unscanned = false
  	order_unscanned = false
  	#puts "Processng Kit product"+self.scanned_qty.to_s
  	if self.scanned_qty < self.order_item.qty * self.product_kit_skus.qty
  		self.scanned_qty = self.scanned_qty + 1
  		if self.scanned_qty ==  self.order_item.qty * self.product_kit_skus.qty
  			self.scanned_status = 'scanned'
  		else
  			self.scanned_status = 'partially_scanned'
  		end
  		self.save
  		#puts "Status:"+self.scanned_status


	  	#need to update order item quantity,
	  	# for this calculate minimum of order items
	  	#update order item status
	  	min = self.order_item.order_item_kit_products.first.scanned_qty
	  	self.order_item.order_item_kit_products.each do |kit_product|
	  		if kit_product.scanned_status != 'scanned'
	  			order_item_unscanned = true
	  		end
	  		min = kit_product.scanned_qty if min > kit_product.scanned_qty
	  	end
	  	self.order_item.scanned_qty = min
	  	if order_item_unscanned
	  		self.order_item.scanned_status = 'partially_scanned'
	  	else
	  		#puts "Order Item Scanned Qty"+self.order_item.scanned_qty.to_s
	  		#self.order_item.scanned_qty = self.order_item.scanned_qty + 1
			if self.order_item.scanned_qty == self.order_item.qty
	  			self.order_item.scanned_status = 'scanned'
	  		end
	  	end
	  	self.order_item.save

	  	#update order status
	  	self.order_item.order.order_items.each do |order_item|
	  		if order_item.scanned_status != 'scanned'
	  			order_unscanned = true
	  		end
	  	end
	  	if order_unscanned
	  		self.order_item.order.status = 'awaiting'
	  	else
        	self.order_item.order.set_order_to_scanned_state
	  	end
	  	self.order_item.order.save
  	end
  end
end
