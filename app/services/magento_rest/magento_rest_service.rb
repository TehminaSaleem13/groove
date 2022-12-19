# frozen_string_literal: true

module MagentoRest
  class MagentoRestService
    def initialize(attrs = {})
      @store = attrs[:store]
      @credential = @store.magento_rest_credential
    end

    def check_connection
      unless @credential.access_token && @credential.oauth_token_secret
        return { status: false, message: "Either access token or oauth_token_secret doesn't exist, Please go through the authentcation process again" }
      end

      begin
        response = check_availability
        return get_connection_message(response)
      rescue Exception => e
        return { status: false, message: e }
      end
    end

    private

    def check_availability
      response = magento_rest_client.check_connection
      return default_404_response if response.code == 404 && response['messages'].blank?

      parsed_json = begin
                        JSON.parse(response)
                    rescue StandardError
                      response
                      end
    end

    def magento_rest_client
      if @credential.store_version == '2.x'
        Groovepacker::MagentoRestV2::Client.new(@credential)
      else
        Groovepacker::MagentoRest::Client.new(@credential)
      end
    end

    def default_404_response
      response = {}
      response['messages'] = { 'error' => [
        {
          'code' => 404,
          'message' => 'API not responding'
        }
      ] }
      response
    end

    def get_connection_message(response)
      err_msg = begin
                    response['messages']['error'].first['message']
                rescue StandardError
                  nil
                  end
      if err_msg
        return { status: false, message: err_msg }
      elsif response && (response['messages'].try(:class) == String || response['message'].try(:class) == String)
        return { status: false, message: response['messages'] || response['message'] }
      end

      { status: true, message: 'Connection tested successfully' }
    end
  end
end
