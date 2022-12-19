# frozen_string_literal: true

module Groovepacker
  module Teapplix
    class Client < Base
      def orders(import_item)
        combined_response = {}
        start_date = get_import_start_date(@credential, import_item)
        return combined_response if @account_name.blank? || @username.blank? || @password.blank?

        status_to_import = ''
        if @credential.import_open_orders
          status_to_import = "&start_date=#{start_date}&not_shipped=1"
        elsif @credential.import_shipped
          status_to_import = "&ship_date_s=#{start_date}"
        end
        return combined_response if status_to_import.blank?

        order_url = "https://www.teapplix.com/h/#{@account_name}/ea/admin.php?User=#{@username}&Passwd=#{@password}&Action=Report&Subaction=OrderRun&combine=combine"
        order_url += status_to_import
        response = get(order_url, true)
        combined_response['orders'] = response
        combined_response
      end

      def products
        combined_response = {}
        return combined_response if @account_name.blank? || @username.blank? || @password.blank?

        response = get("https://www.teapplix.com/h/#{@account_name}/ea/admin.php?User=#{@username}&Passwd=#{@password}&Action=Export&Subaction=inventory_products", false)
        combined_response['products'] = response
        combined_response
      end

      def fetch_inventory_for_products
        combined_response = {}
        return combined_response if @account_name.blank? || @username.blank? || @password.blank?

        url = "https://www.teapplix.com/h/#{@account_name}/ea/admin.php?User=#{@username}&Passwd=#{@password}&Action=Export&Subaction=inventory_quantity_report"
        response = get(url, false)
        combined_response['inventories'] = response
        combined_response
      end

      def update_inventory_qty_on_teapplix(csv_url)
        return combined_response if @account_name.blank? || @username.blank? || @password.blank?

        url = "https://www.teapplix.com/h/#{@account_name}/ea/admin.php?User=#{@username}&Passwd=#{@password}&Action=Upload&Subaction=Inventory&upload=#{csv_url}"
        response = post(url, false)
      end

      private

      def get(url, get_formatted)
        parsed_url = URI.parse(url)
        http = Net::HTTP.new(parsed_url.host, 443)
        http.use_ssl = true
        resp, resp_data = http.get(parsed_url.to_s)
        json_response = csv_to_json(resp.body, get_formatted)
        json_response
      end

      def put(url, body = {})
        response = HTTParty.put(url,
                                body: body.to_json,
                                headers: {
                                  'Content-Type' => 'text/csv',
                                  'Accept' => 'text/csv'
                                })
      end

      def post(url, body = {})
        response = HTTParty.post(url,
                                 body: body.to_json,
                                 headers: {
                                   'Content-Type' => 'text/csv',
                                   'Accept' => 'text/csv'
                                 })
      end

      def get_import_start_date(credential, import_item)
        if import_item.import_type == 'deep'
          days_back_to_import = begin
                                    import_item.days.to_i.days
                                rescue StandardError
                                  4.days
                                  end
          last_import = DateTime.now.in_time_zone - days_back_to_import
        else
          last_import = begin
                          credential.last_imported_at.to_datetime - 1.day
                        rescue StandardError
                          (DateTime.now.in_time_zone - 4.days)
                        end
        end
        last_import = last_import.to_date.strftime('%Y/%m/%d')
        last_import
      end

      def csv_to_json(response_body, get_formatted = true)
        csv = CSV.new(response_body, headers: true)
        json_response = csv.to_a.map(&:to_hash)
        json_response -= [{}]
        json_response = begin
                            json_response.as_json
                        rescue StandardError
                          {}
                          end
        json_response = get_formatted_orders(json_response) if get_formatted
        json_response
      rescue Exception => e
        puts e.message
        puts e.backtrace
      end

      def get_formatted_orders(json_response)
        response_orders = []
        txn_ids = json_response.each.map { |order| order['txn_id'] }.compact.uniq
        txn_ids.each do |txn_id|
          orders_group = json_response.select { |order| order['txn_id'] == txn_id }
          order = orders_group.first.except('item_name', 'item_number', 'item_sku', 'location', 'xref3', 'quantity', 'subtotal', 'item_description')
          order['items'] = []
          orders_group.each do |single_order|
            order['items'] << single_order.slice('item_name', 'item_number', 'item_sku', 'location', 'xref3', 'quantity', 'subtotal', 'item_description')
          end
          response_orders << order
        end
        response_orders
        end
    end
  end
end
