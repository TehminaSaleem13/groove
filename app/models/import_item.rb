class ImportItem < ActiveRecord::Base
  belongs_to :order_import_summary
  belongs_to :store
  attr_accessible :status, :store_id, :previous_imported,
                  :success_imported, :import_type, :store,
                  :current_increment_id, :current_order_items,
                  :current_order_imported_item, :to_import, :message, :days,
                  :updated_orders_import
  after_save :emit_data_to_user


  def emit_data_to_user
    if self.order_import_summary.nil?
      summary = OrderImportSummary.top_summary
    else
      summary = self.order_import_summary
    end
    unless summary.nil?
      summary.emit_data_to_user(true) if eligible_to_update_ui
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

  def eligible_to_update_ui
    status_changed = self.changes["status"].present?
    remainder = ((self.success_imported || 0) + (self.previous_imported || 0) + (self.updated_orders_import || 0))%10
    eligible = remainder==0 ? true : false
    next_order = self.changes["success_imported"].present? || self.changes["previous_imported"].present? ||self.changes["updated_orders_import"].present?
    return status_changed || (eligible && next_order)
  end
end
