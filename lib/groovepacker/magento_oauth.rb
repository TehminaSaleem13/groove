module Groovepacker
  class MagentoOauth
    
    def initialize(attrs={})
      @host = attrs[:host]
      @store_admin_url = attrs[:store_admin_url]
      @consumer_api_key = attrs[:api_key]
      @consumer_api_secret = attrs[:api_secret]
      @oauth_varifier = attrs[:oauth_varifier]
    end

    def generate_authorize_url(result)
      begin
        consumer = OAuth::Consumer.new(@consumer_api_key, @consumer_api_secret, { 
          request_token_path: '/oauth/initiate',
          access_token_path: '/oauth/token',
          authorize_path: '/admin/oauth_authorize',
          site: @host
        })
        request_token = consumer.get_request_token
        authorized_url = "#{@store_admin_url}/oauth_authorize?oauth_token=#{request_token.token}"
        HTTParty.get(authorized_url)
        current_tenant = Apartment::Tenant.current
        Rails.cache.write("#{current_tenant}_magento_request_token", request_token, timeToLive: 600.seconds)

        $redis.set("#{current_tenant}_magento_request_token", request_token)
        raise "301 \"Moved Permanently\"" unless authorized_url.include?(@host)
        result['authorized_url'] = authorized_url
      rescue Exception => ex
        result['status'] = false
        result['message'] = get_formatted_error(ex)
      end
      return result
    end

    def generate_access_token(credential, result)
      begin
        current_tenant = Apartment::Tenant.current
        request_token = Rails.cache.read("#{current_tenant}_magento_request_token")
        access_token = request_token.get_access_token(oauth_verifier: @oauth_varifier)
        credential.access_token = access_token.token
        credential.oauth_token_secret = access_token.secret
        credential.save
        result['access_token'] = credential.access_token
        Rails.cache.delete("#{current_tenant}_magento_request_token")
      rescue Exception => ex
        result['status'] = false
        result['message'] = ex
      end
      return result
    end

    private
      def get_formatted_error(ex)
        if ex.message=="401 Unauthorized"
          msg = "Authorization failed, apparently due to an incorrect key or secret."
        elsif ex.message=="getaddrinfo: Name or service not known" || ex.message=="301 \"Moved Permanently\""
          msg = "Invalid store url or store admin url"
        else
          msg = "Something went wrong. Please make sure that the credentials you entered are correct"
        end
        return msg
      end

  end
end