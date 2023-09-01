# frozen_string_literal: true

module Webhooks
  module Shopify
    class ShopifyWebhookService
      def initialize(resource)
        @client = Groovepacker::ShopifyRuby::Client.new(resource)
      end

      def activate_webhooks
        hooks_topics = @client.list_webhooks&.map { |hook| hook['topic'] } || []
        return if has_minimum_matching_topics?(hooks_topics, ['orders/create', 'orders/updated'], 2)

        register_default_webhooks
      end

      def de_activate_webhooks
        topics_list = ['orders/create', 'orders/updated']
        delete_matching_webhooks(topics_list)
      end

      private

      def has_minimum_matching_topics?(hooks_topics, topics_list, min_count)
        (topics_list & hooks_topics).size >= min_count
      end

      def register_default_webhooks
        attrs_list = [
          {
            "webhook": {
              "address": "https://#{Apartment::Tenant.current}.groovepackerapi.com/webhooks/orders_create",
              "topic": 'orders/create',
              "format": 'json'
            }
          },
          {
            "webhook": {
              "address": "https://#{Apartment::Tenant.current}.groovepackerapi.com/webhooks/orders_update",
              "topic": 'orders/updated',
              "format": 'json'
            }
          }
        ]
        
        attrs_list.each { |attrs| @client.register_webhook(attrs) }
      end

      def delete_matching_webhooks(topics_list)
        @client.list_webhooks&.each do |webhook|
          @client.delete_webhook(webhook['id']) if topics_list.include?(webhook['topic'])
        end
      end
    end
  end
end
