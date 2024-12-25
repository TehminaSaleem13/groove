# frozen_string_literal: true

class GrooveBulkActions < ApplicationRecord
  after_save :emit_data_to_tenant

  # attr_accessible :identifier, :activity, :total, :completed, :status, :current, :messages, :cancel

  def emit_data_to_tenant
    GroovRealtime.emit('pnotif', { type: 'groove_bulk_actions', data: self }, :tenant)
  end

  def self.execute_groove_bulk_action(activity, params, current_user, orders = nil)
    groove_bulk_actions = update_groove_bulk_actions(activity, params)
    current_tenant = Apartment::Tenant.current
    bulkaction_id = groove_bulk_actions.id
    username = current_user.username
    orders ||= {}
    $redis.set("bulk_action_delete_data_#{current_tenant}_#{bulkaction_id}", Marshal.dump(orders)) if params['action'] == 'delete_orders'
    $redis.set("bulk_action_duplicate_data_#{current_tenant}_#{bulkaction_id}", Marshal.dump(orders)) if params['action'] == 'duplicate_orders'
    $redis.set("bulk_action_data_#{current_tenant}_#{bulkaction_id}", Marshal.dump(orders)) if params['action'] == 'change_orders_status'
    $redis.set("bulk_action_clear_assigned_tote_data_#{current_tenant}_#{bulkaction_id}", Marshal.dump(orders)) if params['action'] == 'clear_assigned_tote'
    $redis.set("bulk_action_assign_orders_to_users_#{current_tenant}_#{bulkaction_id}", Marshal.dump(orders)) if params['action'] == 'assign_orders_to_users'
    $redis.set("bulk_action_assign_rfo_orders_#{current_tenant}_#{bulkaction_id}", Marshal.dump(orders)) if params['action'] == 'assign_rfo_orders'
    $redis.set("bulk_action_deassign_orders_to_users_#{current_tenant}_#{bulkaction_id}", Marshal.dump(orders)) if params['action'] == 'deassign_orders_from_users'
    delay(run_at: 1.seconds.from_now, queue: 'do_bulk_action', priority: 95).execute_relevant_action(activity, current_tenant, params, bulkaction_id, username)
    # self.execute_relevant_action(activity, current_tenant, params, bulkaction_id, username)
  end

  def self.update_groove_bulk_actions(activity, params)
    groove_bulk_actions = GrooveBulkActions.new
    groove_bulk_actions.identifier = params['controller'] == 'orders' ? 'orders' : 'product'
    groove_bulk_actions.activity = activity
    groove_bulk_actions.current = ''
    groove_bulk_actions.save
    groove_bulk_actions
  end

  def self.execute_relevant_action(activity, current_tenant, params, bulkaction_id, username)
    bulk_actions = params['controller'] == 'orders' ? Groovepacker::Orders::BulkActions.new : Groovepacker::Products::BulkActions.new
    case true
    when activity == 'status_update'
      bulk_actions.status_update(current_tenant, params, bulkaction_id, username)
    when activity == 'delete' && params['controller'] == 'orders'
      bulk_actions.delete(current_tenant, bulkaction_id, params)
      track_user(current_tenant, params, 'Order Delete', "#{params['controller'].capitalize} Delete")
    when activity == 'delete' && params['controller'] == 'products'
      bulk_actions.delete(current_tenant, params, bulkaction_id, username)
    when activity == 'duplicate' && params['controller'] == 'orders'
      bulk_actions.duplicate(current_tenant, bulkaction_id, username)
    when activity == 'duplicate' && params['controller'] == 'products'
      bulk_actions.duplicate(current_tenant, params, bulkaction_id)
    when activity == 'export'
      bulk_actions.export(current_tenant, params, bulkaction_id, username)
    when activity == 'product_barcode_label' || activity == 'order_product_barcode_label' && params['controller'] == 'products'
      bulk_actions.barcode_labels_generate(current_tenant, params, bulkaction_id, username)
    when activity == 'clear_assigned_tote' && params['controller'] == 'orders'
      bulk_actions.clear_assigned_tote(current_tenant, bulkaction_id, params[:user_id])
    when activity == 'assign_orders_to_users' && params['controller'] == 'orders'
      bulk_actions.assign_orders_to_users(current_tenant, bulkaction_id, params[:user_id], params[:users])
    when activity == 'assign_rfo_orders' && params['controller'] == 'orders'
      bulk_actions.assign_rfo_orders(current_tenant, bulkaction_id, username, params[:no_of_orders])
    when activity == 'deassign_orders_from_users' && params['controller'] == 'orders'
      bulk_actions.deassign_orders_from_users(current_tenant, bulkaction_id, params[:user_id], params[:users])
    end
  end

  def self.track_user(tenant, params, name, title)
    ahoy = Ahoy::Event.new
    ahoy.name = name
    ahoy.properties = {
      title: title,
      tenant: tenant,
      store_id: nil,
      user_id: params[:user_id]
    }
    ahoy.time = Time.current
    ahoy.save!
  end
end
