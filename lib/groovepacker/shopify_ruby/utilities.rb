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
          permission_url = session.create_permission_url(scope,
                                                         "http://admin." + ENV["SHOPIFY_REDIRECT_HOST"] +
                                                           auth_shopify_path(id: shopify_credential.store, tenant_name:
                                                                                                           tenant_name + "&" + is_admin.to_s)
          )
          permission_url
        end
      end
    end
  end
end
