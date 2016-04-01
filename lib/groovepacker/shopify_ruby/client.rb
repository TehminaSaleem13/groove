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

      def products
        page_index = 1
        combined_response = {}
        combined_response["products"] = []
        while page_index
          puts "======================Fetching Page #{page_index}======================"
          query_opts = {"page" => page_index, "limit" => 100}.as_json
          response = HTTParty.get("https://#{shopify_credential.shop_name}.myshopify.com/admin/products", 
                                    query: query_opts, 
                                    headers: {
                                    "X-Shopify-Access-Token" => shopify_credential.access_token,
                                    "Content-Type" => "application/json",
                                    "Accept" => "application/json"
                                  })
          page_index = page_index + 1
          combined_response["products"] << response["products"]
          combined_response["products"] = combined_response["products"].flatten
          break if (response["products"].blank? || response["products"].count < 100)
        end
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

      def get_variant(product_variant_id)
        response = HTTParty.get("https://#{shopify_credential.shop_name}.myshopify.com/admin/variants/#{product_variant_id}", 
                                headers: { 
                                  "X-Shopify-Access-Token" => shopify_credential.access_token, 
                                  "Content-Type" => "application/json", 
                                  "Accept" => "application/json" 
                                })
        #unless sku.blank?
        #  response["variants"] = response["variants"].select {|variant| variant["sku"]==sku} rescue {}
        #  response = response["variants"].first || {}
        #end
        return response["variant"] || {}
      end
      
      def update_inventory(sync_option, attrs)
				
				response = HTTParty.put("https://#{shopify_credential.shop_name}.myshopify.com/admin/variants/#{sync_option.shopify_product_variant_id}", 
                                body: attrs.to_json,
                                headers: { 
                                  "X-Shopify-Access-Token" => shopify_credential.access_token, 
                                  "Content-Type" => "application/json", 
                                  "Accept" => "application/json" 
                                })
      end
      
    end
  end
end
