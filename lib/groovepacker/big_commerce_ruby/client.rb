module Groovepacker
  module BigCommerceRuby
    class Client < Base
      def orders(credential, import_item)
        page_index = 1
        options = {}
        combined_response = {}
        combined_response["orders"] = []
        options[:min_date_modified] = get_min_date_modified(credential, import_item)
        options[:status_id]=11 #11 is status id of 'Awaiting Fulfillment' in BigCommerce
        
        return combined_response if @store_hash.blank?
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

      def products
        page_index = 1
        options = {}
        combined_response = {}
        combined_response["products"] = []
        
        while page_index
          puts = "======================Fetching Page #{page_index}======================"
          options[:page] = page_index
          response = get("https://api.bigcommerce.com/#{@store_hash}/v2/products", options)
          break if response.blank?
          page_index += 1
          combined_response["products"] << response
        end
        
        combined_response["products"] = combined_response["products"].flatten
        combined_response
      end


      def product(product_id)
        get("https://api.bigcommerce.com/#{@store_hash}/v2/products/#{product_id}")
      end

      def order_on_demand(order_id)
        get("https://api.bigcommerce.com/#{@store_hash}/v2/orders/#{order_id}")
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

      def update_product_inv(product_url, attrs={})
        put(product_url, attrs)
      end

      def update_product_sku_inv(sku_url, attrs={})
        put(sku_url, attrs)
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

        def put(url, body={})
          response = HTTParty.put(url,
                                  body: body.to_json,
                                  headers: {
                                    "X-Auth-Token" => @access_token,
                                    "X-Auth-Client" => client_id,
                                    "Content-Type" => "application/json",
                                    "Accept" => "application/json"
                                  }
                                )
        end

        def get_min_date_modified(credential, import_item)
          if import_item.import_type=='deep'
            days_back_to_import = import_item.days.to_i.days rescue 4.days
            last_import =  DateTime.now - days_back_to_import
          else
            last_import = credential.last_imported_at.to_datetime rescue (DateTime.now - 4.days)
          end
          return last_import
        end

    end
  end
end
