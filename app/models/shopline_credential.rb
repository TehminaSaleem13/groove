# frozen_string_literal: true

class ShoplineCredential < ApplicationRecord
  attr_writer :permission_url

  belongs_to :store

  include AhoyEvent
  after_commit :log_events

  serialize :temp_cookies, Hash

  def log_events
    if saved_changes.present? && saved_changes.keys != ['updated_at'] && saved_changes.keys != %w[updated_at last_imported_at]
      track_changes(title: 'ShoplineCredential Changed', tenant: Apartment::Tenant.current,
                    username: User.current.try(:username) || 'GP App', object_id: id, changes: saved_changes)
    end
  end

  def get_status
    val = ''
    val = 'on_hold' if on_hold_status?
    val = 'unshipped' if unshipped_status?
    val = 'partial' if partial_status?
    val = 'shipped' if shipped_status?
    val
  end

  def push_inv_location
    @push_inv_location ||= locations.first
  end

  def pull_inv_location
    @pull_inv_location ||= locations.first
  end

  def locations
    @locations ||= Groovepacker::ShoplineRuby::Client.new(self).locations
  end
end
