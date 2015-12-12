module Groovepacker
  module BigCommerceRuby
    class Base
      include Rails.application.routes.url_helpers
      attr_accessor :big_commerce_credential, :client_id

      def initialize(big_commerce_credential)
        @store_hash = big_commerce_credential.store_hash.gsub('-','/') rescue nil
  	    @access_token = big_commerce_credential.access_token
  	    @endpoint = "https://api.bigcommerce.com"
      end


	  def client_id
	    @client_id ||= ENV['BC_CLIENT_ID']
	  end
    end
  end
end