module MagentoRest
  class MagentoRestService
    
    def initialize(attrs={})
      @store = attrs[:store]
      @credential = @store.magento_rest_credential
    end

    def check_connection
      unless @credential.access_token && @credential.oauth_token_secret
        return {status: false, message: "Either access token or oauth_token_secret doesn't exist, Please go through the authentcation process again"}
      end
      
      begin
        response = check_availability
        if response && response["message"]
          return {status: false, message: response["message"]}
        end
        return {status: true, message: "Connection tested successfully"}
      rescue Exception => ex
        return {status: false, message: ex}
      end
      
    end

    private
      def check_availability
        if @credential.store_version=='2.x'
					client = Groovepacker::MagentoRestV2::Client.new(@credential)
				else
					client = Groovepacker::MagentoRest::Client.new(@credential)
				end
        response = client.check_connection
        parsed_json = JSON.parse(response) rescue response
      end
  end
end
