class OrderImportSummary < ActiveRecord::Base
	belongs_to :store
	has_many :import_items
	attr_accessible :user_id, :status
end