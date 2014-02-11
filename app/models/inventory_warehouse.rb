class InventoryWarehouse < ActiveRecord::Base
  attr_accessible :location, :name

  has_many :users
  has_many :product_inventory_warehousess
end
