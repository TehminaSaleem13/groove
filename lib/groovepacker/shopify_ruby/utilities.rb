module Groovepacker
  module ShopifyRuby
    class Utilities < Base
      def permission_url(tenant_name)
        session = ShopifyAPI::Session.new(
          shopify_credential.shop_name + ".myshopify.com"
        )
        scope = [
          "read_orders", 
          "write_orders", 
          "read_products",
          "write_products"
        ]
        permission_url = session.create_permission_url(scope, 
          "http://"+ tenant_name + "." + ENV["SHOPIFY_REDIRECT_HOST"] + 
          auth_shopify_path(shopify_credential.store)
        )
        permission_url
      end
    end
  end
end