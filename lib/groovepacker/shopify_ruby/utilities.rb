module Groovepacker
  module ShopifyRuby
    class Utilities < Base
      def permission_url(tenant_name, is_admin = false)
        unless shopify_credential.shop_name.nil?
          session = ShopifyAPI::Session.new(
            shopify_credential.shop_name + ".myshopify.com"
          )
          scope = [
            "read_orders",
            "write_orders",
            "read_products",
            "write_products"
          ]
          permission_url = session.create_permission_url(scope, redirect_url)
          permission_url
        end
      end

      def redirect_url
        if Rails.env=="development"
          return "http://admin.#{ENV["SHOPIFY_REDIRECT_HOST"]}/shopify/auth"
        else
          return "https://admin.#{ENV["SHOPIFY_REDIRECT_HOST"]}/shopify/auth"
        end
      end
    end
  end
end
