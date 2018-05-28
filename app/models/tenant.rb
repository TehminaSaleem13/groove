class Tenant < ActiveRecord::Base
  attr_accessible :name, :duplicate_tenant_id, :initial_plan_id, :is_modified, :magento_tracking_push_enabled, :is_multi_box, :orders_delete_days
  validates :name, uniqueness: true
  has_one :subscription
  has_one :access_restriction

  before_destroy :remove_subscriber_from_campaignmonitor

  def remove_subscriber_from_campaignmonitor
    initialize_campaingmonitor.remove_subscriber_from_lists
  end

  def initialize_campaingmonitor
    @cm ||= Groovepacker::CampaignMonitor::CampaignMonitor.new(subscriber: self.subscription)
  end
end
