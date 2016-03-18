module Groovepacker
  module Teapplix
    class Client < Base
      def orders(import_item)
        options = {}
        combined_response = {}
        start_date = get_import_start_date(@credential, import_item)
        return combined_response if @account_name.blank? || @username.blank? || @password.blank?
        status_to_import = ""
        if @credential.import_open_orders
          status_to_import = "&not_shipped=1"
        elsif @credential.import_shipped
          status_to_import = "&shipped=1"
        end
        return combined_response if status_to_import.blank?
				order_url = "https://www.teapplix.com/h/#{@account_name}/ea/admin.php?User=#{@username}&Passwd=#{@password}&Action=Report&Subaction=OrderRun&combine=combine&start_date=#{start_date}"
        order_url = order_url+status_to_import
        response = get(order_url, options, true)
        combined_response["orders"] = response
        combined_response
      end
      
      def products
        options = {}
        combined_response = {}
        
        return combined_response if @account_name.blank? || @username.blank? || @password.blank?
        
				response = get("https://www.teapplix.com/h/#{@account_name}/ea/admin.php?User=#{@username}&Passwd=#{@password}&Action=Export&Subaction=inventory_products", options, false)
        combined_response["products"] = response
        combined_response
      end
      
      private
        def get(url, query_opts={}, get_formatted)
          parsed_url = URI.parse(url)
					http = Net::HTTP.new(parsed_url.host, 443)
					http.use_ssl = true
          resp, resp_data = http.get(parsed_url.to_s)
          json_response = csv_to_json(resp.body, get_formatted)
          return json_response
        end

        def put(url, body={})
          response = HTTParty.put(url,
                                  body: body.to_json,
                                  headers: {
                                    "Content-Type" => "application/json",
                                    "Accept" => "application/json"
                                  }
                                )
        end

        def get_import_start_date(credential, import_item)
          if import_item.import_type=='regular'
            days_back_to_import = import_item.days.to_i.days rescue 4.days
            last_import =  DateTime.now - days_back_to_import
          else
            last_import = credential.last_imported_at.to_datetime-1.day rescue (DateTime.now - 4.days)
          end
          last_import = last_import.to_date.strftime("%Y/%m/%d")
          return last_import
        end
        
        def csv_to_json(response_body, get_formatted=true)
          csv = CSV.new(response_body, :headers => true, :header_converters => :symbol, :converters => :all)
          json_response = csv.to_a.map {|row| row.to_hash}
          json_response = json_response - [{}]
          json_response = get_formatted_orders(json_response) if get_formatted
          return json_response
        end
        
        def get_formatted_orders(json_response)
          response_orders = []
          txn_ids = json_response.each.map {|order| order[:txn_id]}.compact.uniq
          txn_ids.each do |txn_id|
						orders_group = json_response.select {|order| order[:txn_id] == txn_id }
						order = orders_group.first.except(:item_name, :item_number, :item_sku, :location, :xref3, :quantity, :subtotal, :item_description)
						order[:items] = []
						orders_group.each do |single_order|
							order[:items] << single_order.slice(:item_name, :item_number, :item_sku, :location, :xref3, :quantity, :subtotal, :item_description)
						end
						response_orders << order
					end
					return response_orders
				end

    end
  end
end
