class CsvMapping < ActiveRecord::Base
  attr_accessible :order_map, :product_map, :store_id
  serialize :order_map
  serialize :product_map
end
