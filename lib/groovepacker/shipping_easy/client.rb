module Groovepacker
  module ShippingEasy
    # Shipstation Ruby Rest Client
    class Client

      def initialize(shipping_easy_credential)
        @credential = shipping_easy_credential
        @api_key = shipping_easy_credential.api_key
        @api_secret = shipping_easy_credential.api_secret
        @last_imported_at = @credential.last_imported_at
      end

      def orders(statuses, importing_time)
        page_index = 1
        combined_response = {}
        combined_response["orders"] = []
        last_import = @credential.last_imported_at rescue (importing_time - 4.days)
        filters = {page: page_index, per_page: 100, status: statuses, last_updated_at: last_import.to_s}
        filters = filters.merge(api_key_and_secret)
        

        return combined_response if @api_key.blank? || @api_secret.blank?
        while page_index
          response = ::ShippingEasy::Resources::Order.find_all(filters)
          combined_response["orders"] += response["orders"]
          break if response["orders"].length < 100
          page_index += 1
        end
        combined_response
      end

      def api_key_and_secret
        {api_key: @api_key, api_secret: @api_secret}
      end

    end
  end
end
