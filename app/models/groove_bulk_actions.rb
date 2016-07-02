class GrooveBulkActions < ActiveRecord::Base
  after_save :emit_data_to_tenant

  attr_accessible :identifier, :activity, :total, :completed, :status, :current, :messages, :cancel

  def emit_data_to_tenant
    GroovRealtime::emit('pnotif', {type: 'groove_bulk_actions', data: self}, :tenant)
  end

  def self.execute_groove_bulk_action(activity, params, current_user, orders=nil)
    groove_bulk_actions = update_groove_bulk_actions(activity, params)
    current_tenant = Apartment::Tenant.current
    bulkaction_id = groove_bulk_actions.id
    username = current_user.username
    self.delay(run_at: 1.seconds.from_now).execute_relevant_action(
        activity, current_tenant, params, bulkaction_id, username, orders)
  end

  def self.update_groove_bulk_actions(activity, params)
    groove_bulk_actions = GrooveBulkActions.new
    groove_bulk_actions.identifier = params["controller"] == "orders" ? "orders" : "product"
    groove_bulk_actions.activity = activity
    groove_bulk_actions.current = ''
    groove_bulk_actions.save
    groove_bulk_actions
  end

  def self.execute_relevant_action(activity, current_tenant, params, bulkaction_id, username, orders_or_products)
    bulk_actions = params["controller"] == "orders" ? Groovepacker::Orders::BulkActions.new : Groovepacker::Products::BulkActions.new
    case activity
    when 'status_update'
      bulk_actions.status_update(current_tenant, params, bulkaction_id, username, orders_or_products)
    when 'delete'
      bulk_actions.delete(current_tenant, params, bulkaction_id, username)
    when 'duplicate'
      bulk_actions.duplicate(current_tenant, params, bulkaction_id)
    when 'export'
      bulk_actions.export(current_tenant, params, bulkaction_id, username)
    end
  end

end
