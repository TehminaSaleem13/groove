class ImportItems < ActiveRecord::Base
	belongs_to :order_import_summary
	attr_accessible :status, :store_id, :previous_imported, :success_imported
end