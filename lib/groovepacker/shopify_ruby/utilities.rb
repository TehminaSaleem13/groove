# frozen_string_literal: true

module Groovepacker
  module ShopifyRuby
    class Utilities < Base
      def permission_url(_tenant_name, _is_admin = false)
        return if shopify_credential.shop_name.blank?

        session = ShopifyAPI::Session.new(shopify_credential.shop_name + '.myshopify.com')
        scope = %w[read_products write_products read_orders write_orders read_all_orders read_fulfillments write_fulfillments]
        session.create_permission_url(scope, redirect_url)
      end

      def redirect_url
        protocol = Rails.env.development? ? 'http://' : 'https://'
        "#{protocol}admin.#{ENV['SITE_HOST']}/shopify/auth"
      end
    end
  end
end
