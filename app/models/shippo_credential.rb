class ShippoCredential < ApplicationRecord
  belongs_to :store

  include AhoyEvent
  after_commit :log_events

  def log_events
    track_changes(title: 'ShippoCredential Changed', tenant: Apartment::Tenant.current,
                  username: User.current.try(:username) || 'GP App', object_id: id, changes: saved_changes) if saved_changes.present? && saved_changes.keys != ['updated_at'] && saved_changes.keys != ['updated_at', 'last_imported_at']
  end
end
