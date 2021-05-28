class OrdersImportSummary < ActiveRecord::Base
  belongs_to :store, optional: true
  # attr_accessible :error_message, :previous_imported, :status, :success_imported, :total_retrieved
end
