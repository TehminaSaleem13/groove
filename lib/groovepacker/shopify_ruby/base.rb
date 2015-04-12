module Groovepacker
  module ShopifyRuby
    class Base
      include Rails.application.routes.url_helpers
      attr_accessor :shopify_credential
      def initialize(shopify_credential)
        ShopifyAPI::Session.setup(
          {
            :api_key => ENV['SHOPIFY_API_KEY'], 
            :secret => ENV['SHOPIFY_SHARED_SECRET']
          }
        )
        self.shopify_credential = shopify_credential
      end
    end
  end
end