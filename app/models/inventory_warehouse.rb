class InventoryWarehouse < ActiveRecord::Base
  attr_accessible :location, :name

  has_many :users, :dependent => :nullify
  has_many :product_inventory_warehousess

  validates_presence_of :name
  validates_uniqueness_of :name
end
