module Groovepacker
  module MagentoRest
    class Base
      include Rails.application.routes.url_helpers

      def initialize(magento_rest_credential)
        @consumer_key = magento_rest_credential.api_key
				@consumer_secret = magento_rest_credential.api_secret
				@access_token = magento_rest_credential.access_token
				@oauth_token_secret = magento_rest_credential.oauth_token_secret
				@endpoint = "https://www.groovepacker.com/store"
        @credential_id = magento_rest_credential.id
      end
      
    end
  end
end
