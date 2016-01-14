module Groovepacker
  module MagentoRest
    class Client < Base
      def orders
        credential = get_credential
        method = 'GET'
        uri = "#{host_url}/api/rest/orders"
        #last_import = credential.last_imported_at.to_datetime rescue (DateTime.now - 4.days)
        filters = {}
        #from_date = (DateTime.now - 4.days).strftime("%Y-%m-%d %H:%M:%S")
        #to_date = DateTime.now.strftime("%Y-%m-%d %H:%M:%S")
        #filters = {"filter[1]['attribute']" => "created_at", "filter[1]['from']" => from_date, "filter[1]['to']" => to_date}
        orders = {}
        page_index = 1
        while page_index
          puts "=======================Fetching page #{page_index}======================="
          filters = {"page" => "#{page_index}", "limit" => "10"}.merge(filters)
          response = fetch(method, uri, parameters, filters)
          
          page_index += 1
          orders = orders.merge(response)
          response_length = response.length rescue 0
          break if response_length<10 || page_index==10
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
          filters = {"page" => "#{page_index}", "limit" => "10"}
          response = fetch(method, uri, parameters, filters)
          page_index += 1
          products = products.merge(response)
          response_length = response.length rescue 0
          break if response_length<10 || page_index==50
        end
        return products

      end

      def product(product_id, filters={})
        method = 'GET'
        uri = "#{host_url}/api/rest/products/#{product_id}"
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
          params_copy = params_copy.merge(filters_or_data)
          signature_base_string = signature_base_string(method, uri, params_copy)
          params['oauth_signature'] = url_encode(sign(signing_key, signature_base_string))
          header_string = header(params)
          data = {}
          data["filters_or_data"] = filters_or_data
          response = request_update_data(header_string, uri, method, data)
        end

        def signing_key
          @consumer_secret + '&' + @oauth_token_secret
        end

        def generate_nonce(size=8)
          Base64.encode64(OpenSSL::Random.random_bytes(size)).gsub(/\W/, '')
        end

        def parameters
          params = {
            'oauth_consumer_key' => @consumer_key,
            'oauth_nonce' => generate_nonce,
            'oauth_signature_method' => 'HMAC-SHA1',
            'oauth_timestamp' => Time.now.getutc.to_i.to_s,
            'oauth_token' => @access_token,
            'oauth_version' => '1.0'
          }
        end

        #where signature_base_string function is:

        def signature_base_string(method, uri, params)
          encoded_params = params.sort.collect{ |k, v| url_encode("#{k}=#{v}") }.join('%26')
          method + '&' + url_encode(uri) + '&' + encoded_params
        end

        def url_encode(string)
          CGI::escape(string)
        end

        def sign(key, base_string)
          digest = OpenSSL::Digest.new('sha1')
          hmac = OpenSSL::HMAC.digest(digest, key, base_string)
          Base64.strict_encode64(hmac).chomp.gsub(/\n/, '')
        end
		
        def header(params)
          header = 'OAuth realm="",'
          params.each do |k, v|
            header += "#{k}=\"#{v}\","
          end
          header += " "
          header.slice(0..-3) # chop off last ", "
        end

        def request_update_data(header, base_uri, method, data={})
          #url = URI.parse(base_uri)
          #http = Net::HTTP.new(url.host, 443)
          #http.use_ssl = true
          data_params = data["filters_or_data"] || {}
          if method == 'PUT'
            response = HTTParty.put(base_uri, body: data_params, headers: { "Authorization" => header, "Content-Type" => "application/json", "Accept" => "application/json" })
            #resp, resp_data = http.put(url.path, put_data, { 'Authorization' => header, 'Accept' => 'application/json', 'Content-Type' => 'application/json' })
          elsif method == 'GET'
            response = HTTParty.get(base_uri, query: data_params, headers: { "Authorization" => header, "Content-Type" => "application/json", "Accept" => "application/json" })
            #url.query = URI.encode_www_form(data["filters_or_data"]) unless data["filters_or_data"].blank?
            #resp, resp_data = http.get(url.to_s, { 'Authorization' => header })
          end
          response rescue nil
        end
    end
  end
end
