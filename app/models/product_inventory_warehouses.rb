class ProductInventoryWarehouses < ActiveRecord::Base
  belongs_to :product
  attr_accessible :qty, :alert

  belongs_to :inventory_warehouse


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
    if self.allocated_qty > allocated_qty
      self.sold_inv = self.sold_inv + allocated_qty
      self.allocated_qty = self.allocated_qty - allocated_qty
    else
      result &= false
    end
    result
  end

end
