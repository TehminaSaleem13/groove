# frozen_string_literal: true

module Groovepacker
  module ShopifyRuby
    class Base
      include Rails.application.routes.url_helpers
      attr_accessor :shopify_credential

      def initialize(shopify_credential)
        self.shopify_credential = shopify_credential
      end
    end

    class Result
      attr_accessor :response, :errors, :next_page_info

      def initialize
        @response = nil
        @errors = []
      end

      def success!(response)
        @response = response
        @next_page_info = response.try(:next_page_info)
        @errors = []
      end

      def failure!(error_message)
        @errors << error_message
      end

      def success?
        @errors.empty?
      end
    end
  end
end
