# frozen_string_literal: true

class OrderImportSummary < ActiveRecord::Base
  has_many :import_items

  belongs_to :store
  belongs_to :user

  after_save :emit_data_to_user

  def self.top_summary
    order('updated_at desc').first
  end

  def emit_data_to_user(send_data = false)
    require 'open-uri'
    return true unless saved_changes['status'].present? || send_data

    GroovRealtime.emit('import_status_update', import_data, :tenant)
  end

  def import_data(with_progress = false)
    result = {}
    import_summary = reload
    time_zone = GeneralSetting.time_zone
    import_summary.updated_at += time_zone
    result['import_info'] = import_summary
    result['import_items'] = []
    begin
      lines = CsvImportSummary.where('log_record IS NOT NULL and created_at > ?', Time.now - 30.days).last
      result['summary'] = lines.log_record.gsub(/[,]/, '<br/>').gsub(/[{,}]/, '').gsub(/[:]/, '=>')
    rescue StandardError
      result['summary'] = 'nil'
    end
    import_items = ImportItem.includes(store: [:shipstation_rest_credential]).where('status IS NOT NULL')
    import_items.each do |import_item|
      if import_item.store.nil?
        import_item.destroy
      else
        import_item.updated_at += time_zone
        result['import_items'].push(store_info: import_item.store, import_info: import_item,
                                    show_update: show_update(import_item.store), progress: ((import_item.status == 'in_progress' && with_progress) ? import_item.get_import_item_info(import_item.store&.id) : nil))
      end
    end
    result
  end

  private

  def show_update(store)
    if store.store_type == 'Shipstation API 2' &&
       !store.shipstation_rest_credential.nil? &&
       store.shipstation_rest_credential.warehouse_location_update
      true
    else
      false
    end
  end
end
