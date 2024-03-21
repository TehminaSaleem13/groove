# frozen_string_literal: true

module Webhooks
  module Orders
    class OrderWebhookService
      def initialize(order_id, webhook_id, tenant_name)
        Apartment::Tenant.switch! tenant_name
        @order = Order.find_by(id: order_id)
        @webhook = GroovepackerWebhook.find_by(id: webhook_id)
      end

      def trigger_scanned_order_webhook(tenant_name)
        Apartment::Tenant.switch! tenant_name
        order_data = External::OrderSerializer.new(@order).serializable_hash
        response = HTTParty.post(@webhook.url, body: { data: order_data }) 
        raise 'webhook error' if response.code != 200
      end
    end
  end
end
