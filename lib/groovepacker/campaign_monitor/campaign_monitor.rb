module Groovepacker
  module CampaignMonitor
    class CampaignMonitor
      
      def initialize(attrs={})
        @subscriber = attrs[:subscriber]
        @client = ::Groovepacker::CampaignMonitor::Client.new(subscriber: attrs[:subscriber])
      end

      def add_subscriber_to_lists
        @client.add_subscriber_to_lists
      end

      def remove_subscriber_from_lists
        @client.remove_subscriber_from_lists
      end

      def remove_subscriber_from_new_customers_list
        @client.remove_subscriber_from_new_customers_list
      end

    end
  end
end