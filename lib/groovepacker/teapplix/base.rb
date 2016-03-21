module Groovepacker
  module Teapplix
    class Base
      include Rails.application.routes.url_helpers
      attr_accessor :client_id

      def initialize(teapplix_credential)
        @account_name = teapplix_credential.account_name
  	    @username = teapplix_credential.username
  	    @password = teapplix_credential.password
  	    @credential = teapplix_credential
      end
      
    end
  end
end
