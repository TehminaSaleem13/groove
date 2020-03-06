class ImportItem < ActiveRecord::Base
  belongs_to :order_import_summary
  belongs_to :store
  attr_accessible :status, :store_id, :previous_imported,
                  :success_imported, :import_type, :store,
                  :current_increment_id, :current_order_items,
                  :current_order_imported_item, :to_import, :message, :days,
                  :updated_orders_import, :import_error, :failed_count, :order_import_summary_id
  #after_save :emit_data_to_user
  #after_save :emit_countdown_data_to_user


  # def emit_data_to_user
  #   if self.order_import_summary.nil?
  #     summary = OrderImportSummary.top_summary
  #   else
  #     summary = self.order_import_summary
  #   end
  #   unless summary.nil?
  #     summary.emit_data_to_user(true) if eligible_to_update_ui
  #   end
  # end

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

  # def eligible_to_update_ui
  #   status_changed = self.saved_changes["status"].present?
  #   remainder = ((self.success_imported || 0) + (self.previous_imported || 0) + (self.updated_orders_import || 0))%10
  #   eligible = remainder==0 ? true : false
  #   next_order = self.saved_changes["success_imported"].present? || self.saved_changes["previous_imported"].present? || self.saved_changes["updated_orders_import"].present?
  #   return status_changed || (eligible && next_order)
  # end

  def emit_countdown_data_to_user
    if self.changes["current_increment_id"].present?
      result = {'progress_info' => self.reload }
      GroovRealtime::emit('countdown_update', result, :tenant)
    end
  end

  def get_import_item_info(store_id)
    result = {}
    current_import = self.success_imported + self.updated_orders_import
    result[:total_imported] = current_import
    result[:remaining_items] = self.to_import - current_import
    result[:completed] =  Order.last(2).first.try(:increment_id)
    result[:in_progess] = self.current_increment_id
    time = Order.last.try(:updated_at) - self.created_at
    if result[:total_imported] != 0
      time_for_one_order = time / result[:total_imported].to_f
      time_for_total_order = time_for_one_order * self.to_import
      time_for_order_imported = time_for_one_order * result[:total_imported]
      time_zone_for_remaining_order = time_for_total_order - time_for_order_imported
      result[:elapsed_time] = Time.at(time_for_order_imported).utc.strftime("%H:%M:%S")
      result[:elapsed_time_remaining] = Time.at(time_zone_for_remaining_order).utc.strftime("%H:%M:%S")
    end
    time_zone = GeneralSetting.last.time_zone.to_i
    time_zone = GeneralSetting.last.dst ? time_zone : time_zone+3600
    last_update = $redis.get("#{Apartment::Tenant.current}_#{store_id}").to_time.utc rescue nil
    last_update = last_update.nil? ? nil : last_update + time_zone
    result[:last_imported_data] = last_update
    result[:store_id] = store_id
    result[:status] = true
    return result
  end
end
