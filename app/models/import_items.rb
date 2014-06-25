class ImportItems < ActiveRecord::Base
	belongs_to :order_import_summaries
end