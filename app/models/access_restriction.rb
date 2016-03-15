class AccessRestriction < ActiveRecord::Base
  attr_accessible :tenant_id, :num_users, :num_shipments, :num_import_sources, :total_scanned_shipments
  has_one :tenant

  after_save :remove_from_new_customers_if_scanned_10

  def remove_from_new_customers_if_scanned_10
    if self.total_scanned_shipments_changed?
      initialize_campaingmonitor.remove_subscriber_from_new_customers_list if self.total_scanned_shipments==10
    end
  end

  def initialize_campaingmonitor
    current_tenant = Apartment::Tenant.current
    subscription = Subscription.find_by_tenant_name(current_tenant)
    @cm = Groovepacker::CampaignMonitor::CampaignMonitor.new(subscriber: subscription)
  end
end
