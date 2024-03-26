# frozen_string_literal: true

module Webhooks
  module Orders
    class OrderScanWebhookService < BaseService
      class << self
        def trigger_scanned_order_webhooks(order_id)
          tenant = Apartment::Tenant.current
          scanned_orders.each do |webhook|
            delay(run_at: 1.seconds.from_now, queue: 'order_scanned_webhook_' + tenant, priority: 95).run(order_id, webhook.id, tenant) if webhook.url.present?
          end
        end

        private

        def scanned_orders
          @scanned_orders ||= GroovepackerWebhook.scanned_order
        end
      end
    end
  end
end
