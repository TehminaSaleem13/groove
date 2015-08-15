class CsvMap < ActiveRecord::Base
  attr_accessible :custom, :map, :kind, :name
  has_one :csv_mapping, :foreign_key => 'product_csv_map_id', :dependent => :nullify
  has_one :csv_mapping, :foreign_key => 'order_csv_map_id', :dependent => :nullify
  has_one :csv_mapping, :foreign_key => 'kit_csv_map_id', :dependent => :nullify
  serialize :map
end
