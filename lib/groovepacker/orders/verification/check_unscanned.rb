# frozen_string_literal: true

module Groovepacker
  module Orders
    module Verification
      class CheckUnscanned
        attr_reader :tenant, :order_id, :request_ip, :current_user, :app_url

        def initialize(tenant, options = {})
          @tenant = tenant
          @order_id = options[:order_id]
          @request_ip = options[:request_ip]
          @current_user = options[:current_user]
          @app_url = options[:app_url]
        end

        def call
          Apartment::Tenant.switch! tenant
          order = Order.find(order_id)

          return if Rails.env.test? || order.reload.status == 'scanned'

          webhook_url = 'https://hooks.slack.com/services/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'

          body = {
            "blocks": [
              {
                "type": 'section',
                "text": {
                  "type": 'mrkdwn',
                  "text": "*[#{tenant}]* Scanned status change failed for Order *[#{order.increment_id}]* at [#{Time.current}]"
                }
              },
              {
                "type": 'section',
                "text": {
                  "type": 'mrkdwn',
                  "text": "*Tenant:* #{tenant}\n*When:* #{Time.current}\n*Order:* #{order.increment_id} [#{order.id}]\n*User:* #{current_user || 'NA'}\n*IP:* #{request_ip || 'NA'}\n*App URL:* #{app_url || 'NA'}"
                }
              }
            ]
          }

          HTTParty.post(webhook_url,
                        body: body.to_json,
                        headers: { 'Content-Type' => 'application/json' })
        rescue StandardError => e
          puts e.backtrace.join(', ')
        end
      end
    end
  end
end
