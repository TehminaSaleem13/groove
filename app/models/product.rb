class Product < ActiveRecord::Base
  belongs_to :store

  attr_accessible :name,
    :product_type,
    :store_product_id,
    :status,
    :spl_instructions_4_packer,
    :spl_instructions_4_confirmation,
    :is_skippable,
    :packing_placement,
    :pack_time_adj,
    :is_kit,
    :kit_parsing,
    :disable_conf_req,
    :store,
    :weight

  has_many :product_skus, :dependent => :destroy
  has_many :product_cats, :dependent => :destroy
  has_many :product_barcodes, :dependent => :destroy
  has_many :product_images, :dependent => :destroy
  has_many :product_kit_skuss, :dependent => :destroy
  has_many :product_inventory_warehousess, :dependent => :destroy
  has_many :order_serial
  has_many :order_items
  has_many :product_kit_activities, dependent: :destroy

  after_save :check_inventory_warehouses

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
      CSV.open("#{folder}/#{ident}.csv",'w',options) do |csv|
        headers= model.column_names.dup
        if ident == :products
          headers.push('primary_sku','primary_barcode','primary_category','primary_image','default_wh_avbl','default_wh_loc_primary','default_wh_loc_secondary')
        end


        csv << headers
        model.all.each do |item|
          data = []
          data = item.attributes.values_at(*model.column_names).dup
          if ident == :products
            data.push(item.primary_sku)
            data.push(item.primary_barcode)
            data.push(item.primary_category)
            data.push(item.primary_image)
            inventory_wh = ProductInventoryWarehouses.where(:product_id=>item.id,:inventory_warehouse_id => InventoryWarehouse.where(:is_default => true).first.id).first
            if inventory_wh.nil?
              data.push('','','')
            else
              data.push(inventory_wh.available_inv,inventory_wh.location_primary,inventory_wh.location_secondary)
            end
          end

          logger.info data
          csv << data
        end
        response[ident] = "#{folder}/#{ident}.csv"
      end
    end
    response
  end

  def check_inventory_warehouses
    if self.product_inventory_warehousess.length == 0
      inventory = ProductInventoryWarehouses.new
      inventory.product = self
      inventory.inventory_warehouse = InventoryWarehouse.where(:is_default => true).first
      inventory.save
      self.product_inventory_warehousess << inventory
      self.save
    end
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
        result &= false if unacknowledged_kit_activities.length > 0
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
	  		item.order.update_order_status unless item.order.nil?
	  	end
	else
	  	#update order items status from onhold to awaiting
	  	@order_items = OrderItem.where(:product_id=>self.id)
	  	@order_items.each do |item|
	  		item.order.update_order_status unless item.order.nil?
	  	end
	end
	result
  end

  def update_due_to_inactive_product
    if self.status == 'inactive'
      kit_products  = ProductKitSkus.where(:option_product_id => self.id)
      unless kit_products.empty?
        kit_products.each do |kit_product|
          if kit_product.product.status != 'inactive'
            kit_product.product.status = 'new'
            kit_product.product.save
            order_items = OrderItem.where(:product_id=>kit_product.product.id)
            order_items.each do |item|
              item.order.update_order_status unless item.order.nil?
            end
          end
        end
      end
      @order_items = OrderItem.where(:product_id=>self.id)
      @order_items.each do |item|
        item.order.update_order_status unless item.order.nil?
      end
    end
  end

  def set_product_status
  	result = true

	  @skus = ProductSku.where(:product_id=>self.id)
  	result &= false if @skus.length == 0

  	@barcodes = ProductBarcode.where(:product_id=>self.id)
  	result &= false if @barcodes.length == 0

    result &= false if unacknowledged_kit_activities.length > 0

  	if result
  		self.status = 'active'
  	else
  		self.status = 'new'
  	end
  	self.save
  end

  def update_available_product_inventory_level(inventory_warehouse_id, purchase_qty, reason)
  	result = true
  	if self.is_kit != 1 or
  		(self.is_kit == 1 and (self.kit_parsing == 'single' or self.kit_parsing == 'depends'))
	     result &= self.update_warehouses_inventory_level(inventory_warehouse_id, self.id,
	 		purchase_qty, reason)
    else
    	if self.kit_parsing == 'individual'
    		#update all kits products inventory warehouses
    		self.product_kit_skuss.each do |kit_item|
	    		result &= self.update_warehouses_inventory_level(inventory_warehouse_id, kit_item.option_product_id,
	  				purchase_qty * kit_item.qty, reason)
    		end
    	end
    end

	result
  end

  def update_allocated_product_sold_level(inventory_warehouse_id, allocated_qty,
    order_item =nil)
   	result = true

  	if self.is_kit != 1 or
  		(self.is_kit == 1 and self.kit_parsing == 'single')
	     result &= self.update_warehouses_sold_level(inventory_warehouse_id, self.id,
	 		allocated_qty)
    else
    	if self.kit_parsing == 'individual'
    		#update all kits products inventory warehouses
    		self.product_kit_skuss.each do |kit_item|
	    		result &= self.update_warehouses_sold_level(inventory_warehouse_id, kit_item.option_product_id,
	  				allocated_qty * kit_item.qty)
    		end
      elsif self.kit_parsing == 'depends'
        logger.info "saving order to scanned"
        logger.info order_item.inspect
        self.product_kit_skuss.each do |kit_sku|
          result &= self.update_warehouses_sold_level(inventory_warehouse_id,
            kit_sku.option_product_id,
          order_item.kit_split_scanned_qty)
        end
        result &= self.update_warehouses_sold_level(inventory_warehouse_id, self.id,
        order_item.single_scanned_qty)
    	end
    end

	result
  end

  def update_warehouses_inventory_level(inv_wh_id, product_id, purchase_qty, reason)
	  result = true
  	prod_warehouses = ProductInventoryWarehouses.where(:inventory_warehouse_id =>
  		inv_wh_id).where(:product_id => product_id)

  	unless prod_warehouses.length == 1
  		result &= false
  	end

  	unless !result
  		prod_warehouses.each do |wh|
  			result = wh.update_available_inventory_level(purchase_qty, reason)
  		end
  	end

	  result
  end

  def update_warehouses_sold_level(inv_wh_id, product_id, allocated_qty)
 	result = true
  	prod_warehouses = ProductInventoryWarehouses.where(:inventory_warehouse_id =>
  		inv_wh_id).where(:product_id => product_id)

  	unless prod_warehouses.length == 1
  		result &= false
  	end
    logger.info('Allocated Qty which has been sold:'+allocated_qty.to_s)
  	unless !result
  		prod_warehouses.each do |wh|
  			wh.update_sold_inventory_level(allocated_qty)
		  end
	 end

	result
  end

  def get_total_avail_loc
  	total_avail_loc = 0
  	self.product_inventory_warehousess.each do |inv_wh|
  		total_avail_loc = total_avail_loc + inv_wh.available_inv
  	end
  	total_avail_loc
  end


  def get_total_sold_qty
    total_sold_qty = 0
    self.product_inventory_warehousess.each do |inv_wh|
      inv_wh.sold_inventory_warehouses.each do |sold_wh|
        total_sold_qty += sold_wh.sold_qty
      end
    end
    total_sold_qty
  end

  def get_weight
    result = Hash.new

    #converting oz to gms
    weight_gms = self.weight * 28.349523125

    result['lbs'] = (self.weight / 16).round(2)
    result['oz'] = self.weight
    result['kgs'] = (weight_gms / 1000).round(3)
    result['gms'] = weight_gms.round

    result
  end

  def get_shipping_weight
    result = Hash.new
    weight_gms = self.shipping_weight * 28.349523125
  
    result['lbs'] = (self.shipping_weight / 16).round(2)
    result['oz'] = self.shipping_weight
    result['kgs'] = (weight_gms / 1000).round(3)
    result['gms'] = weight_gms.round

    result
  end

  def get_inventory_warehouse_info(inventory_warehouse_id)
    product_inventory_warehouses =
     ProductInventoryWarehouses.where(:inventory_warehouse_id => inventory_warehouse_id).
      where(:product_id => self.id)
    product_inventory_warehouses.first
  end

  # provides primary sku if exists
  def primary_sku
    self.product_skus.order('product_skus.order ASC').first.sku unless self.product_skus.order('product_skus.order ASC').first.nil?
  end

  def primary_sku=(value)
    primary = self.product_skus.order('product_skus.order ASC').first
    if primary.nil?
      primary = self.product_skus.new
    end
    primary.order = 0
    primary.sku = value
    primary.save
  end

  # provides primary image if exists
  def primary_image
    self.product_images.order('product_images.order ASC').first.image unless  self.product_images.order('product_images.order ASC').first.nil?
  end

  def primary_image=(value)
    primary = self.product_images.order('product_images.order ASC').first
    if primary.nil?
      primary = self.product_images.new
    end
    primary.order = 0
    primary.image = value
    primary.save
  end

  # provides primary barcode if exists
  def primary_barcode
    self.product_barcodes.order('product_barcodes.order ASC').first.barcode unless self.product_barcodes.order('product_barcodes.order ASC').first.nil?
  end

  def primary_barcode=(value)
    primary = self.product_barcodes.order('product_barcodes.order ASC').first
    if primary.nil?
      primary = self.product_barcodes.new
    end
    primary.order = 0
    primary.barcode = value
    primary.save
  end

  # provides primary category if exists
  def primary_category
    self.product_cats.first.category unless self.product_cats.first.nil?
  end

  def primary_category=(value)
    primary = self.product_cats.first
    if primary.nil?
      primary = self.product_cats.new
    end
    primary.category = value
    primary.save
  end

  def primary_warehouse
    self.product_inventory_warehousess.where(inventory_warehouse_id:
      InventoryWarehouse.where(:is_default => true).first.id).first
  end

  def unacknowledged_kit_activities
    product_kit_activities.
      where('activity_type in (:types)', types: 'deleted_item').
      where(acknowledged: false)
  end

  def get_product_weight(weight)
    unless self.weight_format.nil?
      if self.weight_format=='lb'
        @lbs =  16 * weight[:lbs].to_f
      elsif self.weight_format=='oz'
        @oz = weight[:oz].to_f
      elsif self.weight_format=='kg'
        @kgs = 1000 * weight[:kgs].to_f
        @kgs * 0.035274
      else
        @gms = weight[:gms].to_f
        @gms * 0.035274
      end
    else
      if GeneralSetting.get_product_weight_format=='lb'
        @lbs =  16 * weight[:lbs].to_f
      elsif GeneralSetting.get_product_weight_format=='oz'
        @oz = weight[:oz].to_f
      elsif GeneralSetting.get_product_weight_format=='kg'
        @kgs = 1000 * weight[:kgs].to_f
        @kgs * 0.035274
      else
        @gms = weight[:gms].to_f
        @gms * 0.035274
      end
    end
  end

  def get_show_weight_format
    unless self.weight_format.nil?
      return self.weight_format
    else
      return GeneralSetting.get_product_weight_format
    end
  end
end
