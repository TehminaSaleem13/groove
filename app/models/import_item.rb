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

  def self.create_or_update(import_item, credential)
    if import_item.nil?
      import_item = ImportItem.new
      import_item.store_id = credential.store.id
    end
    import_item.status = 'in_progress'
    import_item.current_increment_id = ''
    import_item.success_imported = 0
    import_item.previous_imported = 0
    import_item.current_order_items = -1
    import_item.current_order_imported_item = -1
    import_item.to_import = 1
    import_item.save
    return import_item
  end
end
