module Groovepacker
  module MagentoRest
    class Client < Base
      include Groovepacker::MagentoRest::MagentoRestCommon

      def orders
        credential = get_credential
        method = 'GET'
        uri = "#{host_url}/api/rest/orders"
        last_import = credential.last_imported_at.to_datetime rescue (DateTime.now - 4.days)
        #filters = {}
        #from_date = (DateTime.now - 4.days).strftime("%Y-%m-%d %H:%M:%S")
        #to_date = DateTime.now.strftime("%Y-%m-%d %H:%M:%S")
        #filters = {"filter[1][attribute]" => "created_at", "filter[1][from]" => from_date, "filter[1][to]" => to_date}
        #filters = {"order" => "created_at", "dir" => "dsc"}
        orders = {}
        page_index = 1
        while page_index
          puts "=======================Fetching page #{page_index}======================="
          filters = {"page" => "#{page_index}", "limit" => "10", "order" => "created_at", "dir" => "dsc"}
          response = fetch(method, uri, parameters, filters)
          response = filter_resp_orders_for_last_imported_at(response, last_import, credential)
          
          orders = orders.merge(response)
          response_length = response.length rescue 0
          break if response_length<10
          page_index += 1
        end
        return orders
      end

      def order(order_id, filters={})
        method = 'GET'
        uri = "#{host_url}/api/rest/orders/#{order_id}"
        params = parameters
        fetch(method, uri, params, filters)
      end

      def stock_item(stock_id, filters={})
        method = 'GET'
        uri = "#{host_url}/api/rest/stockitems/#{stock_id}"
        params = parameters
        fetch(method, uri, params, filters)
      end


      def products(filters={})
        method = 'GET'
        uri = "#{host_url}/api/rest/products"
        
        products = {}
        page_index = 1
        while page_index
          puts "=======================Fetching page #{page_index}======================="
          filters = {"page" => "#{page_index}", "limit" => "100", "order" => "entity_id", "dir" => "dsc"}
          response = fetch(method, uri, parameters, filters)
          products = products.merge(response)
          response_length = response.length rescue 0
          break if response_length<100
          page_index += 1
        end
        return products

      end

      def product(product_id, filters={})
        method = 'GET'
        uri = "#{host_url}/api/rest/products/#{product_id}"
        params = parameters
        fetch(method, uri, params, filters)
      end

      def order_item_product(filters={})
        method = 'GET'
        uri = "#{host_url}/api/rest/products"
        params = parameters
        fetch(method, uri, params, filters)
      end

      def product_images(product_id, filters={})
        method = 'GET'
        uri = "#{host_url}/api/rest/products/#{product_id}/images"
        params = parameters
        fetch(method, uri, params, filters)
      end

      def product_categories(product_id, filters={})
        method = 'GET'
        uri = "#{host_url}/api/rest/products/#{product_id}/categories"
        params = parameters
        fetch(method, uri, params, filters)
      end

      def update_product_inv(product_id, filters_or_data={})
        method = 'PUT'
        uri = "#{host_url}/api/rest/stockitems/#{product_id}"
        params = parameters
        response = fetch(method, uri, params, filters_or_data)
      end

      def check_connection(filters={})
        method = 'GET'
        uri = "#{host_url}/api/rest/products"
        filters = {"limit" => "1"}
        response = fetch(method, uri, parameters, filters)
        return response
      end
			
      private
        def host_url
          credential = get_credential
          host_url = credential.host
          host_url = host_url.gsub("http", "https") unless host_url.include?("https")
          return host_url
        end

        def get_credential
          @credential ||= MagentoRestCredential.find_by_id(@credential_id)
        end

        def fetch(method, uri, params, filters_or_data={})
          filters_or_data = filters_or_data.stringify_keys
          params_copy = params
          params_copy = params_copy.merge(filters_or_data) if method=="GET"
          signature_base_string = signature_base_string(method, uri, params_copy)
          params['oauth_signature'] = url_encode(sign(signing_key, signature_base_string))
          header_string = header(params)
          data = {}
          data["filters_or_data"] = filters_or_data
          response = request_update_data(header_string, uri, method, data)
        end

        def filter_resp_orders_for_last_imported_at(response, last_import, credential)
          orders_to_return = {}
          if response.code==404 && response["messages"].blank?
            response = {"messages"=>{"error"=>[{"code"=>404, "message"=>"Connection Failed, click <a href='#/settings/stores/#{credential.store_id}'>here</a> for more info"}]}}
          end
          return response if response["messages"].present?
          return orders_to_return if response.blank?
          response.each { |key, value| orders_to_return[key] = value if value["created_at"].to_datetime > last_import }
          return orders_to_return
        end
    end
  end
end
