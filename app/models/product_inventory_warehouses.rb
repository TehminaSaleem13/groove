class ProductInventoryWarehouses < ActiveRecord::Base
  belongs_to :product
  attr_accessible :qty, :alert

  belongs_to :inventory_warehouse
end
