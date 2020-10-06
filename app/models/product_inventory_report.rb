class ProductInventoryReport < ActiveRecord::Base
	self.inheritance_column = :_type_disabled
	has_and_belongs_to_many :products, join_table: :products_product_inventory_reports
    # attr_accessible :name,:type, :is_locked
end
