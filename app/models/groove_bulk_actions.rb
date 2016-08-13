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
    orders = orders || {}
    $redis.set("bulk_action_delete_data_#{current_tenant}_#{bulkaction_id}",Marshal.dump(orders)) if params['action'] == "delete_orders"
    $redis.set("bulk_action_duplicate_data_#{current_tenant}_#{bulkaction_id}",Marshal.dump(orders)) if params['action'] == "duplicate_orders"
    $redis.set("bulk_action_data_#{current_tenant}_#{bulkaction_id}",Marshal.dump(orders)) if params['action'] ==  "change_orders_status"
    self.delay(run_at: 1.seconds.from_now).execute_relevant_action(activity, current_tenant, params, bulkaction_id, username)
    #self.execute_relevant_action(activity, current_tenant, params, bulkaction_id, username)
  end

  def self.update_groove_bulk_actions(activity, params)
    groove_bulk_actions = GrooveBulkActions.new
    groove_bulk_actions.identifier = params["controller"] == "orders" ? "orders" : "product"
    groove_bulk_actions.activity = activity
    groove_bulk_actions.current = ''
    groove_bulk_actions.save
    groove_bulk_actions
  end

  def self.execute_relevant_action(activity, current_tenant, params, bulkaction_id, username)
    bulk_actions = params["controller"] == "orders" ? Groovepacker::Orders::BulkActions.new : Groovepacker::Products::BulkActions.new
    case true 
    when activity=='status_update'
      bulk_actions.status_update(current_tenant, params, bulkaction_id, username)
    when activity=='delete' && params["controller"]=="orders"
      bulk_actions.delete(current_tenant, bulkaction_id)
    when activity=='delete' && params["controller"]=="products"
      bulk_actions.delete(current_tenant, params, bulkaction_id, username)
    when activity=='duplicate' && params["controller"]=="orders"
      bulk_actions.duplicate(current_tenant, bulkaction_id, username)
    when activity=='duplicate' && params["controller"]=="products"
      bulk_actions.duplicate(current_tenant, params, bulkaction_id)
    when activity=='export'
      bulk_actions.export(current_tenant, params, bulkaction_id, username)
    end
  end

end
