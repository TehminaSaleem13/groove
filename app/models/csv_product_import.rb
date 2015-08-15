class CsvProductImport < ActiveRecord::Base
  attr_accessible :success, :store_id, :current_sku, :status, :total, :cancel, :delayed_job_id
  after_save :emit_data_to_user

  def emit_data_to_user
    GroovRealtime::emit('pnotif', {type: 'csv_product_import', data: self}, :tenant)
  end
end
