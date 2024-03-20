# frozen_string_literal: true

class GroovepackerWebhook < ApplicationRecord
  validates_presence_of :url, :event
  
  enum event: { 'Order Scanned': 'order_scanned' }
  scope :scanned_order, -> { where(event: 'Order Scanned') }
end
