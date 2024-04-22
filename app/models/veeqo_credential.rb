# frozen_string_literal: true

class VeeqoCredential < ApplicationRecord
  belongs_to :store

  include AhoyEvent
  after_commit :log_events

  def log_events
    if saved_changes.present? && saved_changes.keys != ['updated_at'] && saved_changes.keys != %w[updated_at last_imported_at]
      track_changes(title: 'VeeqoCredential Changed', tenant: Apartment::Tenant.current,
                    username: User.current.try(:username) || 'GP App', object_id: id, changes: saved_changes)
    end
  end

  def get_active_statuses
    statuses = []
    statuses.push('awaiting_fulfillment') if awaiting_fulfillment_status?
    statuses.push('shipped') if shipped_status?
    statuses.push('awaiting_amazon_fulfillment') if awaiting_amazon_fulfillment_status?
    statuses
  end
end
