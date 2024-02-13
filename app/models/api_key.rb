# frozen_string_literal: true

class ApiKey < ApplicationRecord
  belongs_to :author, class_name: 'User'

  before_validation do
    self.token = SecureRandom.hex
  end

  validates_presence_of :author

  default_scope { where(deleted_at: nil).where('expires_at IS ? OR expires_at >= ?', nil, Time.current) }
  scope :deleted, -> { unscoped.where.not(deleted_at: nil) }
  scope :expired, -> { unscoped.where('expires_at IS NOT ? AND expires_at < ?', nil, Time.current) }

  def self.active
    ApiKey.first
  end
end
