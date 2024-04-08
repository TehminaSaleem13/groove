# frozen_string_literal: true

module Groovepacker
  module SlackNotifications
    class OrderScanFailure
      attr_reader :tenant, :order, :current_user, :app_url, :request_ip

      DEFAULT_WEBHOOK_URL = ENV.fetch('DEFAULT_SLACK_URL', '')
      WEBHOOK_URL = ENV.fetch('ORDER_SCAN_FAILURE_SLACK_URL', DEFAULT_WEBHOOK_URL)

      def initialize(tenant, options = {})
        @tenant = tenant
        Apartment::Tenant.switch! tenant
        @order = Order.find(options[:order_id])
        @current_user = options[:current_user]
        @app_url = options[:app_url]
        @request_ip = options[:request_ip]
      end

      def call
        return if order.reload.status == 'scanned' || order.order_activities.where(action: 'Order Scanning Complete').where('created_at > ?', 10.seconds.ago).exists?

        tenant_url = "#{ENV.fetch('PROTOCOL', 'http://')}#{Apartment::Tenant.current}.#{ENV.fetch('HOST_NAME', 'localpacker.com')}"
        order_url = "#{tenant_url}/#/orders/all/1/#{order.id}"
        message_body = "[*<#{ tenant_url }|#{tenant}> | #{Rails.env.upcase}*] Scanning failed for Order [*<#{order_url} | #{order.increment_id}>*] at [*#{Time.current}*] on #{app_url || 'NA'} by *#{current_user || 'NA'}*"
        send_message = Groovepacker::SlackNotifications::SendMessage.new({webhook_url: WEBHOOK_URL, message_body: message_body, request_ip: request_ip})
        send_message.call
      rescue StandardError => e
        puts e.backtrace.join(', ')
      end
    end
  end
end
