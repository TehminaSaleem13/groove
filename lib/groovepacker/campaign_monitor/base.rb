module Groovepacker
  module CampaignMonitor
    class Base
      include Rails.application.routes.url_helpers

      def initialize(attrs={})
        @subscriber = attrs[:subscriber]
      end

      def api_key
        ENV['CAMPAIGN_MONITOR_API_KEY']
      end

      def client_id
        ENV['CAMPAIGN_MONITOR_CLIENT_ID']
      end

      def end_point
        "https://api.createsend.com/api/v3.1"
      end

    end
  end
end
