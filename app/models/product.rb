class Product < ActiveRecord::Base
  belongs_to :store

  attr_accessible :name, :product_type, :store_product_id,
				    :status,
					:spl_instructions_4_packer,
					:spl_instructions_4_confirmation,
					:alternate_location,
					:barcode,
					:is_skippable,
					:packing_placement,
					:pack_time_adj,
					:is_kit,
					:kit_skus,
					:kit_parsing,
					:location_primary,
					:inv_wh1_qty,
					:inv_alert_wh1,
					:inv_wh2_qty,
					:inv_alert_wh2,
					:inv_wh3_qty,
					:inv_alert_wh3,
					:inv_wh4_qty,
					:inv_alert_wh4,
					:inv_wh5_qty,
					:inv_alert_wh5,
					:inv_wh6_qty,
					:inv_alert_wh6,
					:inv_wh7_qty,
					:inv_alert_wh7,
					:disable_conf_req

  has_many :product_skus, :dependent => :destroy
  has_many :product_cats, :dependent => :destroy
  has_many :product_barcodes, :dependent => :destroy
  has_many :product_images, :dependent => :destroy
  has_many :product_kit_skuss, :dependent => :destroy
  has_many :product_inventory_warehousess, :dependent => :destroy

  def update_product_status
  	if self.status == "inactive" or self.status == "new"
	  	result = true
	  	@skus = ProductSku.where(:product_id=>self.id)
	  	result &= false if @skus.length == 0

	  	@barcodes = ProductBarcode.where(:product_id=>self.id)
	  	result &= false if @barcodes.length == 0

	  	if result
	  		self.status = 'active'
	  		self.save
	  	end

	  	#update order items status from onhold to awaiting
	  	@order_items = OrderItem.where(:product_id=>self.id)
	  	@order_items.each do |item|
	  		item.order.update_order_status
	  	end
	end
  end

  def set_product_status
  	result = true

	@skus = ProductSku.where(:product_id=>self.id)
  	result &= false if @skus.length == 0

  	@barcodes = ProductBarcode.where(:product_id=>self.id)
  	result &= false if @barcodes.length == 0

  	if result
  		self.status = 'active'
  	else
  		self.status = 'new'
  	end
  	self.save
  end




end
