class ProductInventoryWarehouses < ActiveRecord::Base
  belongs_to :product
  attr_accessible :location, :qty, :alert
end
