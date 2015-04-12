module Groovepacker
  module ShopifyRuby
    class Utilities < Base
      def permission_url
        session = ShopifyAPI::Session.new(
          shopify_credential.shop_name + ".myshopify.com"
        )
        scope = ["write_products"]
        permission_url = session.create_permission_url(scope, 
          ENV["SHOPIFY_REDIRECT_URI"] + auth_shopify_path(shopify_credential)
        )
        permission_url
      end
    end
  end
end