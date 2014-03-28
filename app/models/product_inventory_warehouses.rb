class ProductInventoryWarehouses < ActiveRecord::Base
  belongs_to :product
  attr_accessible :qty, :alert

  belongs_to :inventory_warehouse


  def update_available_inventory_level(purchase_qty)
  	result = true
  	if self.available_inv >= purchase_qty
  		self.available_inv = self.available_inv - purchase_qty
  		self.allocated_inv = self.allocated_inv + purchase_qty
  		self.save
  	else
  		result &= false
  	end

  	result
  end

end
