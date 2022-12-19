# frozen_string_literal: true

module BigCommerce
  class BigCommerceService
    def initialize(attrs = {})
      @store = attrs[:store]
      @credential = BigCommerceCredential.find_by_store_id(@store.try(:id))
    end

    def check_connection
      unless @credential.access_token && @credential.store_hash
        return { status: false, message: "Either access token or store hash doesn't exist, Please go through the installation again" }
      end

      begin
        response = check_availability
        return { status: false, message: response['error'] } if response && response['error']

        return { status: true, message: 'Connection tested successfully' }
      rescue Exception => e
        return { status: false, message: e }
      end
    end

    private

    def check_availability
      response = HTTParty.get("https://api.bigcommerce.com/#{@credential.store_hash}/v2/time",
                              headers: {
                                'X-Auth-Token' => @credential.access_token,
                                'X-Auth-Client' => ENV['BC_CLIENT_ID'],
                                'Content-Type' => 'application/json',
                                'Accept' => 'application/json'
                              })
      parsed_json = begin
                        JSON.parse(response)
                    rescue StandardError
                      response
                      end
    end
  end
end
