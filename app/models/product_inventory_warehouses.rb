class ProductInventoryWarehouses < ActiveRecord::Base
  belongs_to :product
  attr_accessible :qty, :alert

  belongs_to :inventory_warehouse
  has_many :sold_inventory_warehouses

  after_save :send_low_inventory_alert_email


  def update_available_inventory_level(purchase_qty, reason)
  	result = true

    if reason == 'purchase'
    	if self.available_inv >= purchase_qty
    		self.available_inv = self.available_inv - purchase_qty
    		self.allocated_inv = self.allocated_inv + purchase_qty
    		self.save
    	else
    		result &= false
    	end
    else
      if self.allocated_inv >= purchase_qty
        self.allocated_inv = self.allocated_inv - purchase_qty
        self.available_inv = self.available_inv + purchase_qty
        self.save
      else
        result &= false
      end      
    end 

  	result
  end

  def update_sold_inventory_level(allocated_qty)
    result = true
    logger.info('Allocated Qty:'+allocated_qty.to_s)
    if self.allocated_inv >= allocated_qty
      logger.info('Allocated Qty:'+self.allocated_inv.to_s)
      
      sold_inv = SoldInventoryWarehouse.new
      sold_inv.sold_qty = allocated_qty
      sold_inv.product_inventory_warehouses = self
      sold_inv.sold_date = DateTime.now
      sold_inv.save

      self.allocated_inv = self.allocated_inv - allocated_qty
      self.save
    else
      result &= false
    end
    result
  end

  def send_low_inventory_alert_email
    if !GeneralSetting.all.first.nil? && 
      (GeneralSetting.all.first.inventory_tracking ||
        GeneralSetting.all.first.low_inventory_alert_email)
      if self.available_inv <= GeneralSetting.all.first.default_low_inventory_alert_limit
        LowInventoryLevel.delay(run_at: 2.seconds.from_now).notify(GeneralSetting.all.first)
      end
    end
  end

end
