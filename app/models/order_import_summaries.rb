class OrderImportSummaries < ActiveRecord::Base
	has_many :import_items
end