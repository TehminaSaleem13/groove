module Groovepacker
  module ShippingEasy
    # Shipstation Ruby Rest Client
    class Client

      def initialize(shipping_easy_credential)
        @credential = shipping_easy_credential
        @api_key = shipping_easy_credential.api_key
        @api_secret = shipping_easy_credential.api_secret
        @last_imported_at = @credential.last_imported_at
        @store_api_key = shipping_easy_credential.store_api_key
      end

      def orders(statuses, importing_time, import_item, start_time = nil)
        page_index = 1
        combined_response = {"orders" => []}
        filters = { page: page_index, per_page: 200, status: statuses, last_updated_at: @last_imported_at, includes: "products"}
        filters = filters.merge(api_key_and_secret)
        last_import = start_time.present? ? start_time : @credential.last_imported_at rescue (DateTime.now - 4.days)

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
          break if response["orders"].length < 200
          page_index += 1
        end
        combined_response["cleared_orders_ids"] = get_cleared_orders_ids(combined_response["orders"])
        combined_response["orders"] = remove_cleared_and_drop_shipped(combined_response["orders"])
        combined_response["error"] = response["error"]
        Tenant.save_se_import_data("========SE Import Started UTC: #{Time.now.utc} TZ: #{Time.now.utc + (GeneralSetting.last.time_zone.to_i || 0)}", '==Filters', filters, '==Combined Response', combined_response)
        combined_response
      end

      def get_single_order(order)
        filters = {includes: "products", order_number: order, page: 1, per_page: 4, last_updated_at: "1900-04-27T16:42:43Z", status: ["shipped", "ready_for_shipment", "pending", "cleared", "pending_shipment"]} rescue nil
        filters = filters.merge(api_key_and_secret)
        response = ::ShippingEasy::Resources::Order.find_all(filters) rescue nil
        response["cleared_orders_ids"] = get_cleared_orders_ids(response["orders"])
        response["orders"] = remove_cleared_and_drop_shipped(response["orders"])
        Tenant.save_se_import_data("========SE On Demand Import Started UTC: #{Time.now.utc} TZ: #{Time.now.utc + (GeneralSetting.last.time_zone.to_i || 0)}", '==Filters', filters, '==Response', response)
        # if response && response["orders"].count > 1
        #   response["orders"].each_with_index do |odr, index|
        #     unless index == 0
        #       if response["orders"].first["external_order_identifier"] == odr["external_order_identifier"] && response["orders"].first["recipients"].first["original_order"]["store_id"] == odr["recipients"].first["original_order"]["store_id"]
        #         response["orders"].first["recipients"].first["line_items"] << odr["recipients"].first["line_items"]
        #         response["orders"].first["recipients"].first["line_items"].flatten!
        #         # response["orders"].first["shipments"] << odr["shipments"]
        #         # response["orders"].first["shipments"].flatten!
        #       end
        #     end
        #   end
        # end
        response
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
