class OrderImportSummary < ActiveRecord::Base
	belongs_to :store
	has_many :import_items
	attr_accessible :user_id, :status
  after_save :emit_data_to_user

  def self.top_summary
    summary = nil
    summaries = self.order('updated_at desc')
    unless summaries.empty?
      summary = summaries.first
    end
    summary
  end

  def emit_data_to_user
    result = Hash.new
    result['import_info'] = self
    result['import_items'] = []
    import_items = ImportItem.where('order_import_summary_id = '+self.id.to_s+' OR order_import_summary_id is null')
    import_items.all.each do |import_item|
      result['import_items'].push({store_info: import_item.store, import_info: import_item})
    end
    GroovRealtime::emit('import_status_update',result,:tenant)
  end
end
