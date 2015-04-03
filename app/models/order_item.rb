class OrderItem < ActiveRecord::Base
  belongs_to :order
  belongs_to :product

  has_many :order_item_kit_products
  attr_accessible :price, :qty, :row_total, :sku, :product, :product_is_deleted

  after_create :update_inventory_levels_for_packing, :add_kit_products
  before_destroy :update_inventory_levels_for_return
  after_save :update_inventory_levels_for_kit_parsing_depends

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

  def build_basic_item(item)
    result = Hash.new
    result['name'] = item.name
    result['instruction'] = item.spl_instructions_4_packer
    result['confirmation'] = item.spl_instructions_4_confirmation
    result['images'] = item.product_images.order("product_images.order ASC")
    result['sku'] = item.product_skus.order("product_skus.order ASC").first.sku if item.product_skus.length > 0
    result['packing_placement'] = item.packing_placement
    result['barcodes'] = item.product_barcodes.order("product_barcodes.order ASC")
    result['product_id'] = item.id
    result['skippable'] = item.is_skippable
    result['record_serial'] = item.record_serial
    result['click_scan_enabled'] = item.click_scan_enabled
    result['type_scan_enabled'] = item.type_scan_enabled
    result['order_item_id'] = self.id

    result
  end

  def build_single_item(depends_kit)
    result = Hash.new
    if !self.product.nil?
      result = self.build_basic_item(self.product)
      result['product_type'] = 'single'
      if depends_kit
        result['qty_remaining'] =
            (self.qty - self.kit_split_qty) - (self.scanned_qty-self.kit_split_scanned_qty)
      else
        result['qty_remaining'] =
            self.qty - self.scanned_qty
      end
    end
    result
  end

  def build_single_child_item(kit_product,depends_kit)
    child_item = Hash.new
    child_item = build_basic_item(kit_product.product_kit_skus.option_product)
    #overwrite scanned qty from basic build
    child_item['scanned_qty'] = kit_product.scanned_qty

    if depends_kit
      child_item['qty_remaining'] = self.kit_split_qty * kit_product.product_kit_skus.qty -
          kit_product.scanned_qty
    else
      child_item['qty_remaining'] = self.qty * kit_product.product_kit_skus.qty -
          kit_product.scanned_qty
    end

    child_item['kit_packing_placement'] = kit_product.product_kit_skus.packing_order
    child_item['kit_product_id'] = kit_product.id
    child_item
  end

  def build_individual_kit(depends_kit)
    result = Hash.new
    result = build_basic_item(self.product)
    result['product_type'] = 'individual'
    if depends_kit
      result['qty_remaining'] = self.kit_split_qty - self.kit_split_scanned_qty
    else
      result['qty_remaining'] = self.qty - self.scanned_qty
    end
    result['scanned_qty'] = self.scanned_qty
    result['child_items'] = []
    result
  end

  def build_unscanned_single_item(depends_kit = false)
    result = Hash.new
    if !self.product.nil?
      result = self.build_single_item(depends_kit)
      result['scanned_qty'] = self.scanned_qty
    end
    result
  end

  def build_unscanned_individual_kit (depends_kit = false)
    result = Hash.new
    if !self.product.nil?
      result = self.build_individual_kit(depends_kit)
      self.order_item_kit_products.each do |kit_product|
        if !kit_product.product_kit_skus.nil? &&
           !kit_product.product_kit_skus.product.nil? &&
            kit_product.scanned_status != 'scanned'
          child_item = self.build_single_child_item(kit_product,depends_kit)

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
      result = self.build_single_item(depends_kit)
      if depends_kit
        result['scanned_qty'] = self.single_scanned_qty
      else
        result['scanned_qty'] = self.scanned_qty
      end
    end
    result
  end

  def build_scanned_individual_kit(depends_kit = false)
    result = Hash.new
    if !self.product.nil?
      result = self.build_individual_kit(depends_kit)
      if depends_kit
        result['scanned_qty'] = self.kit_split_scanned_qty
      end
      self.order_item_kit_products.each do |kit_product|
        if !kit_product.product_kit_skus.nil? &&
            !kit_product.product_kit_skus.product.nil? &&
            (kit_product.scanned_status == 'scanned' or
                kit_product.scanned_status == 'partially_scanned')
          child_item = self.build_single_child_item(kit_product,depends_kit)
          result['child_items'].push(child_item) if child_item['scanned_qty'] != 0
        end
      end
    end
    result
  end


  def process_item(clicked, username)
    order_unscanned = false

    if self.scanned_qty < self.qty
      total_qty = 0
      if self.product.kit_parsing == 'depends'
        self.single_scanned_qty = self.single_scanned_qty + 1
        set_clicked_quantity(clicked, self.product.primary_sku, username)
        self.scanned_qty = self.single_scanned_qty + self.kit_split_scanned_qty
        total_qty = self.qty - self.kit_split_qty
      else
        self.scanned_qty = self.scanned_qty + 1
        set_clicked_quantity(clicked, self.product.primary_sku, username)
        total_qty = self.qty - self.kit_split_qty
      end
      if self.scanned_qty == self.qty
        self.scanned_status = 'scanned'
      else
        self.scanned_status = 'partially_scanned'
      end
      self.save
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
              (kit_product.scanned_qty % (self.kit_split_qty * kit_product.product_kit_skus.qty) == 0) &&
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
    unless self.product.nil?
      if self.product.is_kit == 1
        self.order_item_kit_products.each do |kit_product|
          kit_product.destroy
        end
      end
    end
    result
  end

  def update_inventory_levels_for_packing(override = false)
    result = true
    self.order.reload
    if !self.order.nil? && self.inv_status != 'allocated' && self.order.status != 'cancelled' && 
      (self.order.status == 'awaiting' or override)
      if !self.product.nil? && !self.order.store.nil? &&
        !self.order.store.inventory_warehouse_id.nil?
        result &= self.product.
          update_available_product_inventory_level(self.order.store.inventory_warehouse_id,
            self.qty, 'purchase')
        
        if !GeneralSetting.all.first.nil? && 
              (GeneralSetting.all.first.inventory_tracking)
          unless result
              if GeneralSetting.all.first.hold_orders_due_to_inventory
                self.order.status = 'onhold'
                self.order.status_reason = 'on_hold_due_to_inventory'
              end
              self.inv_status = 'unallocated'
              self.inv_status_reason = 'on_hold_due_to_inventory'
          else
            self.inv_status = 'allocated'
          end
        end
        self.save
        self.order.save
      end
    end
    result
  end

  def update_inventory_levels_for_return (override = false)
    result = true
    if !self.order.nil? && self.inv_status != 'unallocated' &&
        (self.order.status == 'awaiting' or override)
      if !self.product.nil? && !self.order.store.nil? &&
        !self.order.store.inventory_warehouse_id.nil?
        logger.info('available product inventory level')
        result &= self.product.
          update_available_product_inventory_level(self.order.store.inventory_warehouse_id,
            self.qty, 'return')

        if !GeneralSetting.all.first.nil? && 
              (GeneralSetting.all.first.inventory_tracking)
          unless result
            if GeneralSetting.all.first.hold_orders_due_to_inventory
              self.order.status = 'onhold'
              self.order.status_reason = 'on_hold_due_to_inventory'
            end
            self.inv_status = 'allocated'
            self.inv_status_reason = 'allocated_due_to_low_available_inventory'
          else
            self.inv_status = 'unallocated'
          end
        end
        self.save
        self.order.save
      end
    end
    result
  end

  def add_kit_products
    if !self.product.nil? && self.product.is_kit == 1
      self.product.product_kit_skuss.each do |kit_sku|
        if OrderItemKitProduct.where(:order_item_id=>self.id).
            where(:product_kit_skus_id=>kit_sku.id).length == 0
          order_item_kit_product = OrderItemKitProduct.new
          order_item_kit_product.product_kit_skus = kit_sku
          order_item_kit_product.order_item = self
          order_item_kit_product.save
        end
      end
    end

  end


  def update_inventory_levels_for_kit_parsing_depends()
    result = true
    if !self.product.nil? && self.product.kit_parsing == 'depends'
      changed_hash = self.changes

      # this condition gaurantees a new depends kit has been split dynamically
      if !changed_hash.nil? and (!changed_hash['kit_split_qty'].nil?)


        if (changed_hash['kit_split_qty'][0] < changed_hash['kit_split_qty'][1])
          if !self.order.nil? &&
            (self.order.status == 'awaiting')
            if !self.product.nil? && !self.order.store.nil? &&
              !self.order.store.inventory_warehouse_id.nil?
              #return the single kit product
              result &= self.product.
                update_available_product_inventory_level(self.order.store.inventory_warehouse_id,
                  1, 'return')

              #foreach product skus, update the available inventory levels
              self.product.product_kit_skuss.each do |kit_sku|
                result &= kit_sku.option_product.update_available_product_inventory_level(
                  self.order.store.inventory_warehouse_id,
                  kit_sku.qty, 'purchase')
              end
            end
          end
        elsif (!changed_hash['kit_split_qty'][1].nil? && changed_hash['kit_split_qty'][0] != changed_hash['kit_split_qty'][1])
          #reverse the procedure above. this is most likely used when order is reset
          self.product.product_kit_skuss.each do |kit_sku|
            result &= kit_sku.option_product.update_available_product_inventory_level(
              self.order.store.inventory_warehouse_id,
              changed_hash['kit_split_qty'][0] * kit_sku.qty, 'return')
          end

          result &= self.product.
            update_available_product_inventory_level(self.order.store.inventory_warehouse_id,
              changed_hash['kit_split_qty'][0], 'purchase')
        end
      end
    end

    result
  end

  private

  def set_clicked_quantity(clicked, sku, username)
    if clicked
      self.clicked_qty = self.clicked_qty + 1
      self.order.addactivity("Item with SKU: " + 
      sku + " has been click scanned", username)
    end
  end

end
