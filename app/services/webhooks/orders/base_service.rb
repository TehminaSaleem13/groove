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
          return if response.code.to_s.starts_with?('2')

          log_errors(order_id, webhook_id, tenant_name, response)
        rescue StandardError => e
          log_errors(order_id, webhook_id, tenant_name, { error: e.message, backtrace: e.backtrace.join(', ') })
        end

        private

        def log_errors(order_id, webhook_id, tenant_name, response = {})
          Groovepacker::LogglyLogger.log(Apartment::Tenant.current, 'webhook-errors',
                                         { order_id:, webhook_id:, tenant_name:, response: })
        end

        def api_headers
          headers = {}
          headers[:'X-HMAC-SHA256'] = generate_signature if @webhook.secret_key.present?
          headers
        end

        def generate_signature
          HmacEncryptor.new(@webhook.secret_key, @order_data.to_json).generate_signature
        end
      end
    end
  end
end
