# frozen_string_literal: true

class AccessRestriction < ActiveRecord::Base
  # attr_accessible :tenant_id, :num_users, :num_shipments, :num_import_sources, :total_scanned_shipments, :added_through_ui
  include AhoyEvent

  has_one :tenant

  after_save :remove_from_new_customers_if_scanned_30
  after_commit :log_events

  def remove_from_new_customers_if_scanned_30
    if saved_change_to_total_scanned_shipments?
      initialize_campaingmonitor.remove_subscriber_from_new_customers_list if total_scanned_shipments == 30
    end
  end

  def log_events
    if saved_changes.present? && saved_changes.keys != ['updated_at']
      track_changes(title: 'Access Restriction Settings Changed', tenant: Apartment::Tenant.current,
                    username: User.current.try(:username) || 'GP App', object_id: id, changes: saved_changes)
    end
  end  

  def initialize_campaingmonitor
    current_tenant = Apartment::Tenant.current
    subscription = Subscription.find_by_tenant_name(current_tenant)
    @cm = Groovepacker::CampaignMonitor::CampaignMonitor.new(subscriber: subscription)
  end
end
