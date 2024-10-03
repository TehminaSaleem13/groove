# frozen_string_literal: true

class GroovepackerWebhook < ApplicationRecord
  validates :url, :event, presence: true

  enum event: { 'Order Scanned': 'order_scanned' }
  scope :scanned_order, -> { where(event: 'Order Scanned') }
end
