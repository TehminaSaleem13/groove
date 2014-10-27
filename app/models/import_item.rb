class ImportItem < ActiveRecord::Base
	belongs_to :order_import_summary
	belongs_to :store
	attr_accessible :status, :store_id, :store_type, :previous_imported, :success_imported
  after_save :emit_data_to_user

  def emit_data_to_user
    self.order_import_summary.emit_data_to_user
  end
end
