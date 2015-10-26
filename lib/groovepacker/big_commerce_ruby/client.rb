module Groovepacker
  module BigCommerceRuby
    class Client < Base
      def orders(credential)
        page_index = 1
        options = {}
        combined_response = {}
        combined_response["orders"] = []
        last_import = credential.last_imported_at.to_datetime rescue (DateTime.now - 4.days)
        options[:min_date_modified] = last_import unless last_import.blank?
        
        while page_index
          options[:page] = page_index
          response = get("https://api.bigcommerce.com/#{@store_hash}/v2/orders", options)
          break if response.blank?
          page_index += 1
          combined_response["orders"] << response
        end
        
        combined_response["orders"] = combined_response["orders"].flatten
        combined_response
      end

      def product(product_id)
        get("https://api.bigcommerce.com/#{@store_hash}/v2/products/#{product_id}")
      end

      def order_products(order_products_url)
        get(order_products_url)
      end

      def product_skus(product_skus_url)
        get(product_skus_url)
      end

      def customer(customer_url)
        get(customer_url)
      end
      
      def shipping_addresses(shipping_addresses_url)
        get(shipping_addresses_url)
      end

      def product_categories(categories_url)
        get(categories_url)
      end

      def product_images(categories_url)
        get(categories_url)
      end

      private
        def get(url, query_opts={})
          response = HTTParty.get(url,
                                  query: query_opts,
                                  headers: {
                                    "X-Auth-Token" => @access_token,
                                    "X-Auth-Client" => client_id,
                                    "Content-Type" => "application/json",
                                    "Accept" => "application/json"
                                  }
                                )
          response.parsed_response
        end

    end
  end
end
