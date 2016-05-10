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
        err_msg = response["messages"]["error"].first["message"] rescue nil
        if err_msg
          return { status: false, message: err_msg }
        elsif response && (response["messages"].try(:class)==String || response["message"].try(:class)==String)
          return {status: false, message: response["messages"] || response["message"]}
        end
        return {status: true, message: "Connection tested successfully"}
      rescue Exception => ex
        return {status: false, message: ex}
      end
      
    end

    private
      def check_availability
        response = magento_rest_client.check_connection
        if response.code==404 && response["messages"].blank?
          response = {"messages"=>{"error"=>[{"code"=>404, "message"=>"API not responding"}]}}
        end
        parsed_json = JSON.parse(response) rescue response
      end

      def magento_rest_client
        if @credential.store_version=='2.x'
          return Groovepacker::MagentoRestV2::Client.new(@credential)
        else
          return Groovepacker::MagentoRest::Client.new(@credential)
        end
      end
  end
end
