class ProductInventoryWarehouses < ActiveRecord::Base
  belongs_to :product
  attr_accessible :qty, :alert, :inventory_warehouse, :location_primary, :location_secondary

  belongs_to :inventory_warehouse
  has_many :sold_inventory_warehouses, :dependent => :destroy

  def quantity_on_hand
    self.available_inv + self.allocated_inv
  end

  def quantity_on_hand=(value)
    self.available_inv = value.to_i - self.allocated_inv
  end

end
