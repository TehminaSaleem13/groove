# frozen_string_literal: true

module Groovepacker
  module SlackNotifications
    class SendMessage
      attr_reader :webhook_url, :message_body, :request_ip

      def initialize(tenant, options = {})
        @webhook_url = options[:webhook_url]
        @message_body = options[:message_body]
        @request_ip = options[:request_ip]
      end

      def call
        body = {
          "blocks": [
            {
              "type": 'section',
              "text": {
                "type": 'mrkdwn',
                "text": message_body
              }
            }
          ]
        }

        HTTParty.post(
          webhook_url,
          body: body.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
      rescue StandardError => e
        puts e.backtrace.join(', ')
      end
    end
  end
end
