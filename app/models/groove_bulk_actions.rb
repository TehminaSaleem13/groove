class GrooveBulkActions < ActiveRecord::Base
  after_save :emit_data_to_tenant

  attr_accessible :identifier, :activity, :total, :completed, :status, :current, :messages, :cancel

  def emit_data_to_tenant
    GroovRealtime::emit('pnotif', {type: 'groove_bulk_actions', data: self}, :tenant)
  end

end
