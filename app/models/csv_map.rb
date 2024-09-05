# frozen_string_literal: true

class CsvMap < ApplicationRecord
  include AhoyEvent
  after_commit :log_events
  # attr_accessible :custom, :map, :kind, :name
  has_one :csv_mapping, foreign_key: 'product_csv_map_id', dependent: :nullify
  has_one :csv_mapping, foreign_key: 'order_csv_map_id', dependent: :nullify
  has_one :csv_mapping, foreign_key: 'kit_csv_map_id', dependent: :nullify
  validates :name, uniqueness: { scope: :kind }
  serialize :map

  def log_events
    return unless saved_changes.present? && saved_changes.keys != ['updated_at']

    track_changes(title: 'Csv Map Changed', tenant: Apartment::Tenant.current,
                  username: User.current.try(:username) || 'GP App', object_id: id, changes: saved_changes)
  end
end
