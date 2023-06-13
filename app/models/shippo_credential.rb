class ShippoCredential < ApplicationRecord
  belongs_to :store

  include AhoyEvent
  after_commit :log_events

  def log_events
    track_changes(title: 'ShippoCredential Changed', tenant: Apartment::Tenant.current,
                  username: User.current.try(:username) || 'GP App', object_id: id, changes: saved_changes) if saved_changes.present? && saved_changes.keys != ['updated_at'] && saved_changes.keys != ['updated_at', 'last_imported_at']
  end

  def get_active_statuses
    statuses = []
    statuses.push('PAID') if import_paid?
    statuses.push('AWAITPAY') if import_awaitpay?
    statuses.push('PARTIALLY_FULFILLED') if import_partially_fulfilled?
    statuses.push('SHIPPED') if import_shipped?
    statuses.push('PAID','AWAITPAY','PARTIALLY_FULFILLED','SHIPPED') if import_any?
    statuses
  end
end
