class OrderImportSummary < ActiveRecord::Base
  belongs_to :store
  has_many :import_items
  attr_accessible :user_id, :status, :user, :import_summary_type, :display_summary
  after_save :emit_data_to_user
  belongs_to :user

  def self.top_summary
    summary = nil
    summaries = self.order('updated_at desc')
    unless summaries.empty?
      summary = summaries.first
    end
    summary
  end

  def emit_data_to_user(send_data=false)
    require 'open-uri'
    return true unless (self.changes["status"].present? || send_data)
    result = Hash.new
    import_summary = self.reload
    time_zone = GeneralSetting.last.time_zone.to_i
    import_summary.updated_at += time_zone
    result['import_info'] = import_summary
    result['import_items'] = []
    begin
      #url = ENV['S3_BASE_URL']+'/'+"#{Apartment::Tenant.current}"+'/log/'+"import_order_info_#{Apartment::Tenant.current}.log"
      #lines = open(url).read
      #summary = lines.split("\n").last
      lines = CsvImportSummary.where("log_record IS NOT NULL and created_at > ?", Time.now() - 30.days).last
      result['summary'] = lines.log_record.gsub(/[,]/,"<br/>").gsub(/[{,}]/,"").gsub(/[:]/, "=>")
    rescue
      result['summary'] = "nil"
    end  
    # import_items = ImportItem.where('order_import_summary_id = '+self.id.to_s+' OR order_import_summary_id is null')
    import_items = ImportItem.all
    import_items.each do |import_item|
      if import_item.store.nil?
        import_item.destroy
      else
        import_item.updated_at += time_zone
        result['import_items'].push({store_info: import_item.store, import_info: import_item,
                                     show_update: show_update(import_item.store)})
      end
    end
    GroovRealtime::emit('import_status_update', result, :tenant)
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
