# frozen_string_literal: true

module Webhooks
  module Orders
    class BaseService
      class << self
        def run(order_id, webhook_id, tenant_name)
          Apartment::Tenant.switch! tenant_name
          @order = Order.find_by(id: order_id)
          @webhook = GroovepackerWebhook.find_by(id: webhook_id)
          @order_data = External::OrderSerializer.new(@order).serializable_hash
          response = HTTParty.post(@webhook.url, body: { data: @order_data }, headers: api_headers) 
          raise 'webhook error' if response.code != 200
        end
  
        private
  
        def api_headers
          headers = {}
          headers.merge!({ 'X-HMAC-SHA256': generate_signature }) if @webhook.secret_key.present?
          headers
        end
  
        def generate_signature
          HmacEncryptor.new(@webhook.secret_key, @order_data.to_json).generate_signature
        end
      end
    end
  end
end
