# frozen_string_literal: true

module Groovepacker
  module Orders
    module Verification
      class CheckUnscanned
        attr_reader :tenant, :order_id

        def initialize(tenant, order_id)
          @tenant = tenant
          @order_id = order_id
        end

        def call
          Apartment::Tenant.switch! tenant
          order = Order.find(order_id)

          return true if Rails.env.test? || order.status == 'scanned'

          webhook_url = 'https://hooks.slack.com/services/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'
          HTTParty.post(webhook_url,
                        body: { text: "[#{tenant}] Scanned status change failed for Order [#{order.increment_id}] at [#{Time.current}]" }.to_json,
                        headers: { 'Content-Type' => 'application/json' })
        rescue StandardError => e
          puts e.backtrace.join(', ')
        end
      end
    end
  end
end
