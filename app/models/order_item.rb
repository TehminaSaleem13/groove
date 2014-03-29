class OrderItem < ActiveRecord::Base
  belongs_to :order
  belongs_to :product

  has_many :order_item_kit_products
  attr_accessible :price, :qty, :row_total, :sku
  after_create :update_inventory_levels_for_packing
  before_destroy :update_inventory_levels_for_return


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

  def build_unscanned_single_item(depends_kit = false)
    result = Hash.new

    if !self.product.nil?
      result['name'] = self.product.name
      result['product_type'] = 'single'
      result['image'] = 
        self.product.product_images.first if self.product.product_images.length > 0
      result['images'] = self.product.product_images
      result['sku'] = self.product.product_skus.first.sku if self.product.product_skus.length > 0
      
      if depends_kit
        result['qty_remaining'] = 
          (self.qty - self.kit_split_qty) - (self.scanned_qty-self.kit_split_scanned_qty)
      else
        result['qty_remaining'] = 
          self.qty - self.scanned_qty
      end

      result['scanned_qty'] = self.scanned_qty
      result['packing_placement'] = self.product.packing_placement
      result['barcodes'] = self.product.product_barcodes
      result['product_id'] = self.product.id
      result['order_item_id'] = self.id
    end
    result
  end

  def build_unscanned_individual_kit (depends_kit = false)
    result = Hash.new
    if !self.product.nil?
      result['name'] = self.product.name
      result['product_type'] = 'individual'
      result['image'] = 
        self.product.product_images.first if self.product.product_images.length > 0
      result['images'] = self.product.product_images
      result['sku'] = self.product.product_skus.first.sku if self.product.product_skus.length > 0
      if depends_kit
        result['qty_remaining'] = self.kit_split_qty - self.kit_split_scanned_qty
      else
        result['qty_remaining'] = self.qty - self.scanned_qty
      end
      result['scanned_qty'] = self.scanned_qty
      result['packing_placement'] = self.product.packing_placement
      result['barcodes'] = self.product.product_barcodes
      result['product_id'] = self.product.id
      result['order_item_id'] = self.id
      result['child_items'] = []
      self.order_item_kit_products.each do |kit_product|
        if !kit_product.product_kit_skus.nil? &&
           !kit_product.product_kit_skus.product.nil? &&
            kit_product.scanned_status != 'scanned'
          child_item = Hash.new
          child_item['name'] = kit_product.product_kit_skus.option_product.name
          if kit_product.product_kit_skus.option_product.product_images.length >0
            child_item['image'] = 
              kit_product.product_kit_skus.option_product.product_images.first 
          end
          child_item['images'] = kit_product.product_kit_skus.option_product.product_images
          if kit_product.product_kit_skus.option_product.product_skus.length > 0
            child_item['sku'] = kit_product.product_kit_skus.option_product.product_skus.first.sku 
          end
          if depends_kit
            child_item['qty_remaining'] = self.kit_split_qty * kit_product.product_kit_skus.qty - 
                          kit_product.scanned_qty
            child_item['scanned_qty'] = kit_product.scanned_qty
          else
            child_item['qty_remaining'] = self.qty * kit_product.product_kit_skus.qty - 
              kit_product.scanned_qty
            child_item['scanned_qty'] = kit_product.scanned_qty
          end
          child_item['packing_placement'] = kit_product.product_kit_skus.option_product.packing_placement
          child_item['kit_packing_placement'] = kit_product.product_kit_skus.packing_order

          if kit_product.product_kit_skus.option_product.product_barcodes.length > 0
            child_item['barcodes'] = kit_product.product_kit_skus.option_product.product_barcodes
          end
          child_item['product_id'] = kit_product.product_kit_skus.option_product.id
          child_item['kit_product_id'] = kit_product.id
          result['child_items'].push(child_item) if child_item['qty_remaining'] != 0
        end
      end
      result['child_items'] = result['child_items'].sort_by { |hsh| hsh['kit_packing_placement'] }
    end
    result
  end

  def build_scanned_single_item(depends_kit = false)

    result = Hash.new

    if !self.product.nil?
      result['name'] = self.product.name
      result['product_type'] = 'single'
      result['image'] = 
        self.product.product_images.first if self.product.product_images.length > 0
      result['images'] = self.product.product_images
      result['sku'] = self.product.product_skus.first.sku if self.product.product_skus.length > 0
      if depends_kit
        result['qty_remaining'] = 
          (self.qty - self.kit_split_qty) - (self.scanned_qty-self.kit_split_scanned_qty)
        result['scanned_qty'] = self.single_scanned_qty
      else
        result['qty_remaining'] = 
          self.qty - self.scanned_qty
        result['scanned_qty'] = self.scanned_qty
      end

      result['packing_placement'] = self.product.packing_placement
      result['barcodes'] = self.product.product_barcodes
      result['product_id'] = self.product.id
      result['order_item_id'] = self.id
    end
    result
  end

  def build_scanned_individual_kit(depends_kit = false)
    result = Hash.new

    if !self.product.nil?
      result['name'] = self.product.name
      result['product_type'] = 'individual'
      result['image'] = 
        self.product.product_images.first if self.product.product_images.length > 0
      result['images'] = self.product.product_images
      result['sku'] = self.product.product_skus.first.sku if self.product.product_skus.length > 0
      if depends_kit
        result['qty_remaining'] = self.kit_split_qty - self.kit_split_scanned_qty
        result['scanned_qty'] = self.kit_split_scanned_qty
      else
        result['qty_remaining'] = self.qty - self.scanned_qty
        result['scanned_qty'] = self.scanned_qty
      end
      result['packing_placement'] = self.product.packing_placement
      result['barcodes'] = self.product.product_barcodes
      result['product_id'] = self.product.id
      result['order_item_id'] = self.id
      result['child_items'] = []
      self.order_item_kit_products.each do |kit_product|
        if !kit_product.product_kit_skus.nil? &&
           !kit_product.product_kit_skus.product.nil? &&
            (kit_product.scanned_status == 'scanned' or
              kit_product.scanned_status == 'partially_scanned')

          child_item = Hash.new
          child_item['name'] = kit_product.product_kit_skus.option_product.name
          if kit_product.product_kit_skus.option_product.product_images.length >0
            child_item['image'] = 
              kit_product.product_kit_skus.option_product.product_images.first 
          end
          child_item['images'] = kit_product.product_kit_skus.option_product.product_images
            if kit_product.product_kit_skus.option_product.product_skus.length > 0
            child_item['sku'] = kit_product.product_kit_skus.option_product.product_skus.first.sku 
          end
          if depends_kit
            child_item['qty_remaining'] = self.kit_split_qty * kit_product.product_kit_skus.qty - 
                          kit_product.scanned_qty
            child_item['scanned_qty'] = kit_product.scanned_qty
          else
            child_item['qty_remaining'] = self.qty * kit_product.product_kit_skus.qty - 
              kit_product.scanned_qty
            child_item['scanned_qty'] = kit_product.scanned_qty
          end
          child_item['packing_placement'] = kit_product.product_kit_skus.option_product.packing_placement
          child_item['kit_packing_placement'] = kit_product.product_kit_skus.packing_order
          if kit_product.product_kit_skus.option_product.product_barcodes.length > 0
            child_item['barcodes'] = kit_product.product_kit_skus.option_product.product_barcodes
          end
          child_item['product_id'] = kit_product.product_kit_skus.option_product.id
          child_item['kit_product_id'] = kit_product.id
          result['child_items'].push(child_item) if child_item['scanned_qty'] != 0
        end
      end
    end
    result
  end


  def process_item
    order_unscanned = false
    
    if self.scanned_qty < self.qty
      total_qty = 0
      if self.product.kit_parsing == 'depends'
        self.single_scanned_qty = self.single_scanned_qty + 1
        self.scanned_qty = self.single_scanned_qty + self.kit_split_scanned_qty
        total_qty = self.qty - self.kit_split_qty
      else
        self.scanned_qty = self.scanned_qty + 1
        total_qty = self.qty - self.kit_split_qty
      end
      if self.scanned_qty == self.qty
        self.scanned_status = 'scanned'
      else
        self.scanned_status = 'partially_scanned'
      end
      self.save
      #puts "Order Item Status:" + self.scanned_status
      #update order status
      # self.order.order_items.each do |order_item|
      #   if order_item.scanned_status != 'scanned'
      #     order_unscanned = true
      #   end
      # end
      # if order_unscanned
      #   self.order.status = 'awaiting'
      # else
      #   self.order.set_order_to_scanned_state
      # end
      # self.order.save
    end

  end

  def should_kit_split_qty_be_increased(product_id)
    result = false
    if self.product.is_kit == 1 && self.kit_split && 
        self.product.kit_parsing == 'depends'

        #if no of unscanned items in the kit split qty for the corrseponding item 
        #is greater than 0 and the kit split can be increased in the order item,
        #then the quantity should be increased
        self.order_item_kit_products.each do |kit_product|
          if kit_product.product_kit_skus.option_product.id == product_id && 
              kit_product.scanned_qty != 0 &&
              (kit_product.scanned_qty % 
                (self.kit_split_qty * kit_product.product_kit_skus.qty) == 0) && 
              self.scanned_qty < self.qty
            result = true
          end
        end
    end
    logger.info "result:"+result.to_s

    result
  end

  def remove_order_item_kit_products
    result = true
    if self.product.is_kit == 1
      self.order_item_kit_products.each do |kit_product|
        kit_product.destroy
      end
    end
    result  
  end

  def update_inventory_levels_for_packing(override = false)
    result = true
    if !self.order.nil? && 
      (self.order.status == 'awaiting' or override)
      if !self.product.nil? && !self.order.store.nil? &&
        !self.order.store.inventory_warehouse_id.nil?
        result &= self.product.
          update_available_product_inventory_level(self.order.store.inventory_warehouse_id, 
            self.qty, 'purchase')

        unless result
          self.order.status = 'onhold'
        end
        self.order.save
      end
    end
    result
  end

  def update_inventory_levels_for_return (override = false)
    result = true
    if !self.order.nil? && 
        (self.order.status == 'awaiting' or override)
      if !self.product.nil? && !self.order.store.nil? &&
        !self.order.store.inventory_warehouse_id.nil?
        logger.info('available product inventory level')
        result &= self.product.
          update_available_product_inventory_level(self.order.store.inventory_warehouse_id, 
            self.qty, 'return')

        unless result
          self.order.status = 'onhold'
        end
        self.order.save
      end
    end
    result
  end

end
