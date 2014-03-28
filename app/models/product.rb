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

  def self.to_csv(folder,options= {})
    require 'csv'
    response = {}
    tables = {
      products: self,
      product_barcodes: ProductBarcode,
      product_images: ProductImage,
      product_skus:ProductSku,
      product_cats:ProductCat,
      product_kit_skus: ProductKitSkus,
      product_inventory_warehouses:ProductInventoryWarehouses
    }
    tables.each do |ident,model|
      CSV.open("#{folder}/#{ident}.csv","w",options) do |csv|
        csv << model.column_names
        model.all.each do |item|
          csv << item.attributes.values_at(*model.column_names)
        end
        response[ident] = "#{folder}/#{ident}.csv"
      end
    end
    response
  end

  def update_product_status (force_from_inactive_state = false)
  	#puts "Updating product status"
  	if self.status != 'inactive' || force_from_inactive_state
	  	result = true

      result &= false if (self.name.nil? or self.name == '')

	  	result &= false if self.product_skus.length == 0

	  	result &= false if self.product_barcodes.length == 0

	  	#if kit it should contain kit products as well
	  	if self.is_kit == 1
	  	  result &= false if self.product_kit_skuss.length == 0
	  	  self.product_kit_skuss.each do |kit_product|
	  	  	option_product = Product.find(kit_product.option_product_id)
	  	  	if !option_product.nil? &&
	  	  			option_product.status != 'active'
	  	  		result &= false
	  	  	end
	  	  end
	  	end

	  	if result
	  		self.status = 'active'
	  		self.save
	  	else
	  		self.status = 'new'
	  		self.save
	  	end

	  	# for non kit products, update all kits product statuses where the
	  	# current product is an item of the kit
	  	if self.is_kit == 0
	  		@kit_products  = ProductKitSkus.where(:option_product_id => self.id)
	  		result_kit = true
	  		@kit_products.each do |kit_product|
	  			if kit_product.product.status != 'inactive'
		  			kit_product.product.update_product_status
	  			end
	  		end
	  	end

	  	#update order items status from onhold to awaiting
	  	@order_items = OrderItem.where(:product_id=>self.id)
	  	@order_items.each do |item|
	  		item.order.update_order_status
	  	end
	else
	  	#update order items status from onhold to awaiting
	  	@order_items = OrderItem.where(:product_id=>self.id)
	  	@order_items.each do |item|
	  		item.order.update_order_status
	  	end
	end
	result
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

  def update_available_product_inventory_level(inventory_warehouse_id, purchase_qty)
  	prod_warehouses = ProductInventoryWarehouses.where(:inventory_warehouse_id => 
  		inventory_warehouse_id).where(:product_id => self.id)
  	result = true
  	unless prod_warehouses.length == 1 
  		result &= false 
  	end 

  	unless !result
  		prod_warehouses.each do |wh|
  			wh.update_available_inventory_level(purchase_qty)
		end
	end

	result
  end

end
