class ProductInventoryWarehouses < ActiveRecord::Base
  belongs_to :product
  attr_accessible :qty, :alert, :inventory_warehouse, :location_primary, :location_secondary

  belongs_to :inventory_warehouse
  has_many :sold_inventory_warehouses


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
    if self.allocated_inv >= allocated_qty && allocated_qty!= 0

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

end
