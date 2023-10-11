# frozen_string_literal: true

module Webhooks
  module Shopify
    class ShopifyWebhookService
      def initialize(resource)
        @client = Groovepacker::ShopifyRuby::Client.new(resource)
      end

      def activate_webhooks
        hooks_address = @client.list_webhooks&.map { |hook| hook['address'] } || []
        return if has_minimum_matching_address?(hooks_address, 2)
       
        register_default_webhooks
      end

      def de_activate_webhooks
        delete_matching_webhooks
      end

      private

      def webhook_address_list
        [order_create_webhook, order_update_webhook]
      end

      def has_minimum_matching_address?(hooks_address, min_count)
        (webhook_address_list & hooks_address).size >= min_count
      end

      def order_create_webhook
        "https://#{Apartment::Tenant.current}.#{ENV['SITE_HOST']}/webhooks/orders_create"
      end

      def order_update_webhook
        "https://#{Apartment::Tenant.current}.#{ENV['SITE_HOST']}/webhooks/orders_update"
      end

      def register_default_webhooks
        attrs_list = [
          {
            "webhook": {
              "address": order_create_webhook,
              "topic": 'orders/create',
              "format": 'json',
              "fields": %w[id name]
            }
          },
          {
            "webhook": {
              "address": order_update_webhook,
              "topic": 'orders/updated',
              "format": 'json',
              "fields": %w[id name]
            }
          }
        ]

        attrs_list.each { |attrs| @client.register_webhook(attrs) }
      end

      def delete_matching_webhooks
        @client.list_webhooks&.each do |webhook|
          @client.delete_webhook(webhook['id']) if webhook_address_list.include?(webhook['address'])
        end
      end
    end
  end
end
