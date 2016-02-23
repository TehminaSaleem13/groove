module Groovepacker
  module MagentoRestV2
    module MagentoRestCommon
      #This is a commomn file and is in use at other places as well.
      #So take care while modifying the code.

      #where signature_base_string function is:
      def signature_base_string(method, uri, params)
        encoded_params = params.sort.collect{ |k, v| url_encode("#{k}=#{v}") }.join('%26')
        method + '&' + url_encode(uri) + '&' + encoded_params
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
      		  'oauth_version' => '1.0'
      		}
	      params['oauth_token'] = @oauth_token unless @oauth_token.blank?
	      params['oauth_verifier'] = @oauth_verifier unless @oauth_verifier.blank?
	      return params
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
          response = HTTParty.put(base_uri, body: data_params.to_json, headers: { "Authorization" => header, "Content-Type" => "application/json", "Accept" => "application/json" })
        elsif method == 'POST'
          response = HTTParty.post(base_uri, body: data_params.to_json, headers: { "Authorization" => header, "Content-Type" => "application/json", "Accept" => "application/json" })
        elsif method == 'GET'
          response = HTTParty.get(base_uri, query: data_params, headers: { "Authorization" => header, "Content-Type" => "application/json", "Accept" => "application/json" })
        end
        response rescue nil
      end

    end
  end
end
