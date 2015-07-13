class SoldInventoryWarehouse < ActiveRecord::Base
  attr_accessible :sold_date, :sold_qty

  belongs_to :product_inventory_warehouses
  belongs_to :order_item
end
