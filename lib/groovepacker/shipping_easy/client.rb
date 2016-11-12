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

      def orders(statuses, importing_time, import_item)
        page_index = 1
        combined_response = {"orders" => []}
        filters = { page: page_index, per_page: 100, status: statuses, last_updated_at: @last_imported_at, includes: "products"}
        filters = filters.merge(api_key_and_secret)
        last_import = @credential.last_imported_at rescue (DateTime.now - 4.days)

        if import_item.import_type=='deep'
          days_back_to_import = import_item.days.to_i.days rescue 4.days
          last_import = importing_time - days_back_to_import
        end
        filters[:last_updated_at] = last_import.to_s

        return combined_response if @api_key.blank? || @api_secret.blank?
        while page_index
          filters[:page] = page_index
          response = fetch_orders(filters)
          combined_response["orders"] += response["orders"]
          break if response["orders"].length < 100
          page_index += 1
        end
        combined_response["cleared_orders_ids"] = get_cleared_orders_ids(combined_response["orders"])
        combined_response["orders"] = remove_cleared_and_drop_shipped(combined_response["orders"])
        combined_response["error"] = response["error"]
        combined_response
      end

      def api_key_and_secret
        {api_key: @api_key, api_secret: @api_secret}
      end

      def fetch_orders(filters)
        begin
          response = ::ShippingEasy::Resources::Order.find_all(filters)
        rescue => e
          error = JSON.parse(e.to_s)
          error = error["errors"].first rescue {"message" => 'Something went wrong while fetching orders'}
          response = {"orders" => [], "error" => error}
        end
        response
      end

      def remove_cleared_and_drop_shipped(orders)
        orders.select {|order| ["drop_shipped", "cleared"].exclude?(order["order_status"]) }
      end

      def get_cleared_orders_ids(orders)
        orders.map {|order| order["external_order_identifier"] if order["order_status"]=="cleared" }.compact
      end

    end
  end
end
