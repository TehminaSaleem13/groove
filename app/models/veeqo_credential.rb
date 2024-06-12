# frozen_string_literal: true

class VeeqoCredential < ApplicationRecord
  belongs_to :store

  include AhoyEvent
  after_commit :log_events

  def log_events
    object_changes = saved_changes.except(:last_imported_at, :updated_at, :created_at)
    if object_changes.present?
      track_changes(title: "#{self.class.name} Changed", tenant: Apartment::Tenant.current,
                    username: User.current.try(:username) || 'GP App', object_id: id, changes: saved_changes)
    end
  end

  def get_active_statuses
    statuses = []
    statuses.push('awaiting_fulfillment') if awaiting_fulfillment_status?
    statuses.push('shipped') if shipped_status?
    statuses.push('awaiting_amazon_fulfillment') if awaiting_amazon_fulfillment_status?
    statuses.push('awaiting_stock')
    statuses
  end
end
