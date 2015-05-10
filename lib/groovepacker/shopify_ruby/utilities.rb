module Groovepacker
  module ShopifyRuby
    class Utilities < Base
      def permission_url(tenant_name, is_admin = false)
        session = ShopifyAPI::Session.new(
          shopify_credential.shop_name + ".myshopify.com"
        )
        scope = [
          "read_orders", 
          "write_orders", 
          "read_products",
          "write_products"
        ]
        if is_admin
          subdomain = 'admin'
        else
          subdomain = tenant_name
        end
        puts shopify_credential.inspect
        permission_url = session.create_permission_url(scope, 
          "http://"+ subdomain + "." + ENV["SHOPIFY_REDIRECT_HOST"] + 
          auth_shopify_path(shopify_credential.store, {tenant_name: tenant_name})
        )
        permission_url
      end
    end
  end
end