class ProductInventoryWarehouses < ActiveRecord::Base
  belongs_to :product
  attr_accessible :qty, :alert, :location_primary, :location_secondary, :available_inv, :allocated_inv, :inventory_warehouse_id

  belongs_to :inventory_warehouse

  def quantity_on_hand
    self.available_inv + self.allocated_inv
  end

  def quantity_on_hand=(value)
    self.available_inv = value.to_i - self.allocated_inv
  end

end
