# frozen_string_literal: true

module Groovepacker
  module SlackNotifications
    class OrderScanDiscrepancy
      attr_reader :tenant_name, :tenant, :order_id, :user_name, :app_url, :request_ip

      DEFAULT_WEBHOOK_URL = ENV.fetch('DEFAULT_SLACK_URL', '')
      WEBHOOK_URL = ENV.fetch('ORDER_SCAN_FAILURE_SLACK_URL', DEFAULT_WEBHOOK_URL)

      def initialize(tenant_name, options = {})
        @tenant_name = tenant_name
        @tenant = Tenant.find_by(name: tenant_name)
        @order_id = options[:order_id]
        @user_name = options[:user_name]
        @app_url = options[:app_url]
        @request_ip = options[:request_ip]
      end

      def call
        Apartment::Tenant.switch! tenant_name
        order = Order.find_by(id: order_id)
        return if order.scanned?

        tenant_url = "#{ENV.fetch('PROTOCOL', 'http://')}#{tenant_name}.#{ENV.fetch('HOST_NAME', 'localpacker.com')}"
        order_url = "#{tenant_url}/#/orders/all/1/#{order.id}"
        message_body = "[*<#{ tenant_url }|#{tenant_name}> | #{Rails.env.upcase}*] A dispute detected for Order [*<#{order_url} | #{order.increment_id}>*] at [*#{Time.current}*] on #{app_url || 'NA'} by *#{user_name || 'NA'}*"
        send_message = Groovepacker::SlackNotifications::SendMessage.new({webhook_url: WEBHOOK_URL, message_body: message_body, request_ip: request_ip})
        send_message.call

        mark_order_scanned(order) if tenant.mark_discrepancies_scanned
      rescue StandardError => e
        puts e.backtrace.join(', ')
      end

      def mark_order_scanned(order)
        order.status = 'scanned'
        order.already_scanned = true
        order.scanned_on = Time.current
        order.addactivity('Order verification for this order completed successfully, but the Activity Log is incomplete. This issue has been reported.', 'GroovePacker')
        order.packing_score = order.compute_packing_score
        order.post_scanning_flag = nil
        Tote.where(order_id: order.id).update_all(order_id: nil, pending_order: false)
        order.save
        order.update_access_restriction
        SendStatStream.new.delay(run_at: 1.seconds.from_now, queue: 'export_stat_stream_scheduled_' + tenant_name, priority: 95).build_send_stream(tenant_name, order.id) if !Rails.env.test? && tenant.groovelytic_stat
      end
    end
  end
end
