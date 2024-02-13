# frozen_string_literal: true

module Groovepacker
  module ShoplineRuby
    class Base
      include Rails.application.routes.url_helpers
      attr_accessor :shopline_credential

      def initialize(shopline_credential)
        self.shopline_credential = shopline_credential
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
