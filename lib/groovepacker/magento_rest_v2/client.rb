module Groovepacker
  module MagentoRestV2
    class Client < Groovepacker::MagentoRest::Base
      include Groovepacker::MagentoRest::MagentoRestCommon

      def orders
        credential = get_credential
        method = 'GET'
        uri = "#{api_base_url}/orders"
        last_import = credential.last_imported_at.to_datetime rescue (DateTime.now - 4.days)
        orders = []
        page_index = 1
        previous_response = []
        while page_index
          puts "=======================Fetching page #{page_index}======================="
          #filter_groups = { "0" => {  "filters" => { "0" => { "field" => "created_at", "value" => last_import, "condition_type" => "gt" } } } }
          #filters = { 'search_criteria' => { 'current_page' => page_index, 'page_size' => 10, 'filter_groups' => filter_groups }}
          #filters = {"search_criteria" =>  { "current_page" => page_index, "page_size" => 10, "sort_orders" => [{"field" => "created_at", "direction" => "DESC" }] }}
          #filters = {"searchCriteria" => '', "page" => "#{page_index}", "limit" => "10", "order" => "created_at", "dir" => "dsc"}
          #filters = {"searchCriteria" => ''}

          filters = {
                      "searchCriteria%5Bfilter_groups%5D%5B0%5D%5Bfilters%5D%5B0%5D%5Bfield%5D" => "created_at",
                      "searchCriteria%5Bfilter_groups%5D%5B0%5D%5Bfilters%5D%5B0%5D%5Bvalue%5D" => "#{(last_import-10.day).strftime("%Y-%m-%d")}",
                      "searchCriteria%5Bfilter_groups%5D%5B0%5D%5Bfilters%5D%5B0%5D%5Bcondition_type%5D" => "gt",
                      "searchCriteria%5Bcurrent_page%5D" => page_index,
                      "searchCriteria%5Bpage_size%5D" => 100
                    }
          
          mg_response = fetch(method, uri, parameters, filters)
          if mg_response["message"].present? || mg_response["messages"].present?
            orders = mg_response
            break
          end
          mg_response = {"items"=>[]} if previous_response == mg_response["items"]
          orders = orders.push(mg_response["items"]).flatten
          response_length = mg_response["items"].length rescue 0
          previous_response = mg_response["items"]
          break if response_length<100
          page_index += 1
        end
        orders = filter_resp_orders_for_last_imported_at(orders, last_import)
        return orders
      end

      def order(order_id, filters={})
        method = 'GET'
        uri = "#{api_base_url}/orders/#{order_id}"
        params = parameters
        fetch(method, uri, params, filters)
      end

      def stock_item(sku, filters={})
        method = 'GET'
        uri = "#{api_base_url}/stockItems/#{sku}"
        params = parameters
        fetch(method, uri, params, filters)
      end


      def products(filters={})
        method = 'GET'
        uri = "#{api_base_url}/products"
        
        products = {}
        page_index = 1
        while page_index
          puts "=======================Fetching page #{page_index}======================="
          filters = {"search_criteria" =>  { "current_page" => page_index, "page_size" => 100 }}
          response = fetch(method, uri, parameters, filters)
          unless response["items"].blank?
            response["items"].each {|product| products[product["id"]]=product}
          end
          response_length = response.length rescue 0
          break if response_length<100
          page_index += 1
        end
        return products

      end

      def product(product_id, filters={})
        method = 'GET'
        uri = "#{api_base_url}/products/#{product_id}"
        params = parameters
        fetch(method, uri, params, filters)
      end

      def product_images(product_id, filters={})
        method = 'GET'
        uri = "#{api_base_url}/products/#{product_id}/images"
        params = parameters
        fetch(method, uri, params, filters)
      end

      def product_categories(product_id, filters={})
        method = 'GET'
        uri = "#{api_base_url}/products/#{product_id}/categories"
        params = parameters
        fetch(method, uri, params, filters)
      end

      def update_product_inv(sync_optn, filters_or_data={})
        method = 'PUT'
        uri = "#{api_base_url}/products/#{sync_optn.mg_rest_product_sku}/stockItems/#{sync_optn.mg_rest_product_id}"
        params = parameters
        response = fetch(method, uri, params, filters_or_data)
      end

      def check_connection(filters={})
        method = 'GET'
        uri = "#{api_base_url}/orders"
        #filters = { 'search_criteria' => { 'current_page' => 1, 'page_size' => 2, 'sort_orders' => { '0' => {'field' => 'created_at', 'direction' => 'ASC' } } }}
        #filter_groups = { "0" => {  "filters" => { "0" => { "field" => "price", "value" => "45", "condition_type" => "gt" } } } }
        #filters = { 'search_criteria' => { 'current_page' => 1, 'page_size' => 2, 'filter_groups' => filter_groups }}
        filters = { 'search_criteria' => ''}
        response = fetch(method, uri, parameters, filters)
        return response
      end
			
      private
        def api_base_url
          credential = get_credential
          host_url = credential.host
          #host_url = host_url.gsub("http", "https") unless host_url.include?("https")
          api_url = credential.store_version=="2.x" ? "#{host_url}/rest/V1" : "#{host_url}/api/rest"
          return api_url
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

        def filter_resp_orders_for_last_imported_at(response, last_import)
          orders_to_return = {}
          if response.class==Hash
            return response if response["messages"].present? || response["message"].present?
          end
          return orders_to_return if response.blank?
          response.each { |order| orders_to_return[order["increment_id"]] = order if order["created_at"].to_datetime > last_import }
          return orders_to_return
        end
    end
  end
end
