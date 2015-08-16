module Groovepacker
  module ShopifyRuby
    class Base
      include Rails.application.routes.url_helpers
      attr_accessor :shopify_credential

      def initialize(shopify_credential)
        self.shopify_credential = shopify_credential
      end
    end
  end
end
