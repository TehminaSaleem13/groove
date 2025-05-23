module Groovepacker
  module ShippoRuby
    class Client < Base
      def orders(import_item = nil)
        combined_response = {}
        combined_response['orders'] = []
        cred_last_imported = shippo_credential.last_imported_at
        last_import = if cred_last_imported
                        cred_last_imported.utc.in_time_zone('Eastern Time (US & Canada)').to_datetime.to_s
                      else
                        Order.emit_notification_for_default_import_date(import_item&.order_import_summary&.user_id, shippo_credential.store, nil, 10)
                        (DateTime.now.utc.in_time_zone('Eastern Time (US & Canada)').to_datetime - 10.days).to_s
                      end
        response = HTTParty.get("https://api.goshippo.com/orders?page=1&results=25&start_date=#{last_import}", headers: headers)
        combined_response['orders'] << response['results']

        while response['next'].present?
          import_item&.touch
          response = HTTParty.get(response['next'], headers: headers)
          combined_response['orders'] << response['results']
        end

        combined_response['orders'] = combined_response['orders'].flatten
        combined_response
      end

      def get_ranged_orders(start_date, end_date)
        combined_response = {}
        combined_response['orders'] = []

        response = HTTParty.get("https://api.goshippo.com/orders?start_date=#{start_date.gsub(' ', 'T')}&end_date=#{end_date.gsub(' ', 'T')}", headers: headers)
        combined_response['orders'] = response['results'].flatten
        combined_response
      end

      def get_single_order(order_no)
        response = HTTParty.get("https://api.goshippo.com/orders?q=#{order_no}", headers: headers)
        response['results'][0]
      end

      private
      def headers
        {
          'Authorization' => 'ShippoToken' +' '+shippo_credential.api_key,
          'Content-Type' => 'application/json'
        }
      end
    end
  end
end
