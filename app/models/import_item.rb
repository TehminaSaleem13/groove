class ImportItem < ActiveRecord::Base
	belongs_to :order_import_summary
	attr_accessible :status, :store_id, :store_type, :previous_imported, :success_imported
end