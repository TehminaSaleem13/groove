class ImportItem < ActiveRecord::Base
  belongs_to :order_import_summary
  belongs_to :store
  attr_accessible :status, :store_id, :previous_imported,
                  :success_imported, :import_type, :store,
                  :current_increment_id, :current_order_items,
                  :current_order_imported_item, :to_import,
                  :success_imported
  after_save :emit_data_to_user


  def emit_data_to_user
    if self.order_import_summary.nil?
      summary = OrderImportSummary.top_summary
    else
      summary = self.order_import_summary
    end
    unless summary.nil?
      summary.emit_data_to_user
    end
  end
end
