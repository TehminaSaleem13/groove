module Groovepacker
  module MagentoRestV2
    class Base
      #This is a commomn file and is in use at other places as well.
      #So take care while modifying the code.

      include Rails.application.routes.url_helpers

      def initialize(magento_rest_credential)
        @consumer_key = magento_rest_credential.api_key
        @consumer_secret = magento_rest_credential.api_secret
        @oauth_token = magento_rest_credential.access_token #it is a permanent access_toeken
        @oauth_token_secret = magento_rest_credential.oauth_token_secret
        @endpoint = magento_rest_credential.host
        @credential_id = magento_rest_credential.id
      end

    end
  end
end

