module Groovepacker
  module ShipstationRuby
    module Rest
      # Shipstation Ruby Rest Client
      class Client
        attr_accessor :auth, :client, :endpoint

        def initialize(api_key, api_secret)
          fail ArgumentError unless api_key && api_secret
          @auth = { api_key: api_key, api_secret: api_secret }
          @endpoint = 'https://ssapi.shipstation.com'
        end

        def get_orders(status, ord_placed_after, date_type = 'created_at')
          Rails.logger.info 'Getting orders with status: ' + status
          start_date = order_date_start(
            date_type, ss_format(ord_placed_after)) unless ord_placed_after.nil?
          fetch_orders(status, start_date)
        end

        def products
          Rails.logger.info 'Getting all active products'
          response = query("#{@endpoint}/Products?showInactive=false")
          handle_exceptions(response)
          response.parsed_response
        end

        def get_tracking_number(orderNumber)
          tracking_number = nil
          unless orderNumber.nil?
            order_number_param = '&orderNumber=' + orderNumber.to_s
            Rails.logger.info "Getting shipment with number: #{orderNumber}"
            response = query("#{@endpoint}/Shipments/List?" \
              'page=1&pageSize=100' + URI.encode(order_number_param))
            tracking_number = handle_shipment_response(response, orderNumber)
          end
          tracking_number
        end

        def update_order(orderId, order)
          Rails.logger.info 'Updating order with orderId: ' + orderId.to_s
          response = HTTParty.post('https://ssapi.shipstation.com/Orders/CreateOrder',
                                   body: JSON.dump(order),
                                   headers: {
                                     'Authorization' => authorization_token,
                                     'Content-Type' => 'application/json',
                                     'Accept' => 'application/json'
                                   }, debug_output: $stdout)
          handle_exceptions(response)
          response
        end

        def get_order(orderId)
          Rails.logger.info 'Getting orders with orderId: ' + orderId
          query("#{@endpoint}/Orders/" + orderId)
        end

        def get_tag_id(tag)
          response = query(@endpoint + '/accounts/listtags')
          handle_exceptions(response)
          tags = response.parsed_response
          index = tags.empty? ? nil : tags.index { |x| x['name'] == tag }
          index.nil? ? -1 : tags[index]['tagId']
        end

        def get_orders_by_tag(tag)
          tag_id = get_tag_id(tag)
          response = { 'orders' => [] }
          unless tag_id == -1
            %w(awaiting_payment awaiting_shipment shipped
               on_hold cancelled).each do |status|
              res = find_orders_by_tag_and_status(tag_id, status)
              response['orders'] = response['orders'] + res unless res.nil?
            end
          end
          response
        end

        def find_orders_by_tag_and_status(tag_id, status)
          page_index = 1
          orders = []
          loop do
            response = query("#{@endpoint}/orders/listbytag?orderStatus=" \
              "#{status}&tagId=#{tag_id}&page=#{page_index}&pageSize=100")
            orders += response['orders'] unless response['orders'].nil?
            total_pages = response.parsed_response['pages']
            page_index += 1
            return orders if page_index > total_pages
          end
        end

        def remove_tag_from_order(order_id, tag_id)
          response = HTTParty.post("#{@endpoint}/orders/removetag",
                                   body: { orderId: order_id, tagId: tag_id },
                                   headers: headers)
          handle_exceptions(response)
        end

        def add_tag_to_order(order_id, tag_id)
          response = HTTParty.post("#{@endpoint}/orders/addtag",
                                   body: { orderId: order_id, tagId: tag_id },
                                   headers: headers)
          handle_exceptions(response)
        end

        def inspect
          "#<ShipStationRuby::Client:#{object_id}>"
        end

        private

        def authorization_token
          'Basic ' + Base64.encode64(@auth[:api_key] + ':' +
            @auth[:api_secret]).gsub(/\n/, '')
        end

        def error_status_codes
          [500, 401]
        end

        def query(query)
          response = nil
          loop do
            trial_count = 0
            puts "loop #{trial_count}"
            response = HTTParty.get(query,
                                    headers: headers, 
                                    debug_output: $stdout)
            handle_response(response, trial_count) ? break : trial_count += 1
            break if trial_count >= 5
          end
          puts response.inspect
          response
        end

        def headers
          { 'Authorization' => authorization_token }
        end

        def fetch_orders(status, start_date)
          combined = { 'orders' => [] }
          page_index = 1
          loop do
            res = query("#{@endpoint}/Orders/List?orderStatus=" \
              "#{status}&page=#{page_index}&pageSize=500#{start_date}")
            handle_exceptions(res)
            combined['orders'] = union(combined['orders'],
                                       res.parsed_response['orders'])
            page_index += 1
            return combined if res.parsed_response['orders'].length == 0
          end
        end

        def handle_response(response, trial_count)
          successful_response = false
          if error_status_codes.include?(response.code) ||
             (response.code == 504 && trial_count == 4)
            handle_exceptions(response)
          elsif response.code == 504
            sleep(5)
          else
            successful_response = true
          end
          successful_response
        end

        def handle_shipment_response(response, order_num)
          tracking_number = nil
          unless response.parsed_response['shipments'].nil? ||
                 response.parsed_response['shipments'].empty?
            response.parsed_response['shipments'].each do |s|
              next if s['trackingNumber'].nil? || s['orderNumber'] != order_num
              tracking_number = s['trackingNumber']
              break
            end
          end
          tracking_number
        end

        def order_date_start(import_date_type, order_placed_after)
          if import_date_type == 'created_at'
            "&orderDateStart=#{order_placed_after}"
          elsif %w(modified_at quick_created_at).include?(import_date_type)
            if import_date_type == 'quick_created_at'
              predicate = 'orderDateStart'
            else
              predicate = 'modifyDateStart'
            end
            "&#{predicate}=#{order_placed_after}"
          end
        end

        def ss_format(start_date)
          (start_date.beginning_of_day + Time.zone_offset('PDT').seconds).to_s
            .gsub(' UTC', '').gsub(' ', '%20')
        end

        def union(orders, second_set)
          orders += second_set unless second_set.length == 0
          orders
        end

        def handle_exceptions(response)
          fail Exception, 'Authorization with Shipstation store failed.' \
            ' Please check your API credentials' if response.code == 401
          fail Exception, response.inspect if response.code == 500
          fail Exception, 'Please contact support team. Gateway timeout error'\
            ' from Shipstation API.' if response.code == 504
        end
      end
    end
  end
end
