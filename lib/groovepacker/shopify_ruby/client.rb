module Groovepacker
  module ShopifyRuby
    class Client < Base
      def orders
        page_index = 1
        combined_response = {}
        combined_response["orders"] = []
        response = HTTParty.get('https://'+ shopify_credential.shop_name +
                                  '.myshopify.com/admin/orders',
                                headers: {
                                  "X-Shopify-Access-Token" => shopify_credential.access_token,
                                  "Content-Type" => "application/json",
                                  "Accept" => "application/json"
                                })
        page_index = page_index + 1
        combined_response["orders"] = response["orders"]
        combined_response
      end

      def product(product_id)
        response = HTTParty.get('https://'+ shopify_credential.shop_name +
                                  '.myshopify.com/admin/products/' + product_id.to_s,
                                headers: {
                                  "X-Shopify-Access-Token" => shopify_credential.access_token,
                                  "Content-Type" => "application/json",
                                  "Accept" => "application/json"
                                })
        response
      end
    end
  end
end
