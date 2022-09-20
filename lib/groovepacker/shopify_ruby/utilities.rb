# frozen_string_literal: true

module Groovepacker
  module ShopifyRuby
    class Utilities < Base
      def permission_url(_tenant_name, _is_admin = false)
        return if shopify_credential.shop_name.blank?

        redirect_url + "?shop=#{shopify_credential.shop_name}.myshopify.com&tenant=#{Apartment::Tenant.current}&store=#{shopify_credential.store.id}"
      end

      def redirect_url
        protocol = Rails.env.development? ? 'http://' : 'https://'
        "#{protocol}admin.#{ENV['SITE_HOST']}/shopify/connection_auth"
      end
    end
  end
end
