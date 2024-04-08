# frozen_string_literal: true

module Groovepacker
  module Orders
    module Verification
      class CheckUnscanned
        attr_reader :tenant, :order_id, :request_ip, :current_user, :app_url, :message_body

        WEBHOOK_URL = ENV.fetch('VERIFY_UNSCANNED_SLACK_URL', 'https://hooks.slack.com/services/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')

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

          return if order.reload.status == 'scanned' || order.order_activities.where(action: 'Order Scanning Complete').where('created_at > ?', 10.seconds.ago).exists?

          tenant_url = "#{ENV.fetch('PROTOCOL', 'http://')}#{Apartment::Tenant.current}.#{ENV.fetch('HOST_NAME', 'localpacker.com')}"
          order_url = "#{tenant_url}/#/orders/all/1/#{order.id}"
          message_body = "[*<#{ tenant_url }|#{tenant}> | #{Rails.env.upcase}*] Scanned status change failed for Order [*<#{order_url} | #{order.increment_id}>*] at [*#{Time.current}*] on #{app_url || 'NA'} by *#{current_user || 'NA'}*"
          message_service = Groovepacker::SlackNotifications::SendMessage.new({webhook_url: WEBHOOK_URL, message_body: message_body, request_ip: request_ip})
          message_service.call
        rescue StandardError => e
          puts e.backtrace.join(', ')
        end
      end
    end
  end
end
