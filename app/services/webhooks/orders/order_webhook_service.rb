# frozen_string_literal: true

module Webhooks
  module Orders
    class OrderWebhookService
      def initialize(order, webhook, tenant_name)
        Apartment::Tenant.switch! tenant_name
        @order = order
        @webhook = webhook
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
