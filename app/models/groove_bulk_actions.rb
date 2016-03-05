class GrooveBulkActions < ActiveRecord::Base
  after_save :emit_data_to_tenant

  attr_accessible :identifier, :activity, :total, :completed, :status, :current, :messages, :cancel

  def emit_data_to_tenant
    GroovRealtime::emit('pnotif', {type: 'groove_bulk_actions', data: self}, :tenant)
  end

  def self.execute_groove_bulk_action(activity, params, current_user)
  	bulk_actions = Groovepacker::Products::BulkActions.new
    groove_bulk_actions = GrooveBulkActions.new
    groove_bulk_actions.identifier = 'product'
    groove_bulk_actions.activity = activity
    groove_bulk_actions.current = ''
    groove_bulk_actions.save

    case activity
    when 'status_update'
      bulk_actions.delay(:run_at => 1.seconds.from_now).status_update(Apartment::Tenant.current, params, groove_bulk_actions.id)
    when 'delete'
      bulk_actions.delay(:run_at => 1.seconds.from_now).delete(Apartment::Tenant.current, params, groove_bulk_actions.id, current_user.username)
    when 'duplicate'
      bulk_actions.delay(:run_at => 1.seconds.from_now).duplicate(Apartment::Tenant.current, params, groove_bulk_actions.id)
    when 'export'
      bulk_actions.delay(:run_at => 1.seconds.from_now).export(Apartment::Tenant.current, params, groove_bulk_actions.id, current_user.username)
    end
  end

end
