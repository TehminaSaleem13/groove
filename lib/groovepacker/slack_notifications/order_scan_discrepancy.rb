# frozen_string_literal: true

module Groovepacker
  module SlackNotifications
    class OrderScanDiscrepancy
      attr_reader :tenant, :order_id, :user_name, :app_url, :request_ip

      DEFAULT_WEBHOOK_URL = ENV.fetch('DEFAULT_SLACK_URL', '')
      WEBHOOK_URL = ENV.fetch('ORDER_SCAN_FAILURE_SLACK_URL', DEFAULT_WEBHOOK_URL)

      def initialize(tenant, options = {})
        @tenant = tenant
        @order_id = options[:order_id]        
        @user_name = options[:user_name]
        @app_url = options[:app_url]
        @request_ip = options[:request_ip]
      end

      def call
        Apartment::Tenant.switch! tenant
        order = Order.find_by(id: order_id)

        tenant_url = "#{ENV.fetch('PROTOCOL', 'http://')}#{Apartment::Tenant.current}.#{ENV.fetch('HOST_NAME', 'localpacker.com')}"
        order_url = "#{tenant_url}/#/orders/all/1/#{order.id}"
        message_body = "[*<#{ tenant_url }|#{tenant}> | #{Rails.env.upcase}*] A dispute detected for Order [*<#{order_url} | #{order.increment_id}>*] at [*#{Time.current}*] on #{app_url || 'NA'} by *#{user_name || 'NA'}*"
        send_message = Groovepacker::SlackNotifications::SendMessage.new({webhook_url: WEBHOOK_URL, message_body: message_body, request_ip: request_ip})
        send_message.call
      rescue StandardError => e
        puts e.backtrace.join(', ')
      end
    end
  end
end
