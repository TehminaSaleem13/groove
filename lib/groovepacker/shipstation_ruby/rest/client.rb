module Groovepacker
  module ShipstationRuby
    module Rest
      # Shipstation Ruby Rest Client
      class Client
        attr_accessor :client, :service

        def initialize(api_key, api_secret)
          @service = Groovepacker::ShipstationRuby::Rest::Service.new(api_key, api_secret)
        end

        def get_orders(status, ord_placed_after, date_type = 'created_at')
          Rails.logger.info 'Getting orders with status: ' + status
          start_date = order_date_start(
            date_type, ss_format(ord_placed_after)) unless ord_placed_after.nil?
          fetch_orders(status, start_date)
        end

        def get_shipments(import_from, date_type = 'created_at')
          shipments_after_last_import = []
          start_date = shipment_date_start(date_type, ss_format(import_from))
          page_index=1
          while page_index
            response = @service.query("/shipments?page=#{page_index}&pageSize=200#{start_date}", nil, "get")
            shipments_after_last_import = shipments_after_last_import.push(response["shipments"]).flatten
            break if response["shipments"].count<200
            page_index +=1
          end
          return shipments_after_last_import
        end

        def get_tracking_number(orderId)
          tracking_number = nil
          unless orderId.nil?
            order_number_param = '&orderId=' + orderId.to_s
            Rails.logger.info "Getting shipment with order Id: #{orderId}"
            response = @service.query("/Shipments/List?" \
              'page=1&pageSize=100' + URI.encode(order_number_param), nil, "get")
            tracking_number = handle_shipment_response(response, orderId)
          end
          tracking_number
        end

        def get_order(orderId)
          Rails.logger.info 'Getting orders with orderId: ' + orderId
          @service.query("/orders/" + orderId, nil, "get")
        end

        def get_order_on_demand(orderId, using_tracking_number=false)
          Rails.logger.info 'Getting orders with orderId: ' + orderId
          status_to_fetch = "awaiting_shipment"
          response = @service.query("/orders?orderNumber=#{orderId}&orderStatus=#{status_to_fetch}", nil, "get")
          log_on_demand_order_import(orderId, response, using_tracking_number)
          return response
        end

        def get_order_by_tracking_number(tracking_number)
          on_demand_logger.info("********")
          response = @service.query("/shipments?trackingNumber=#{tracking_number}", nil, "get")
          return {"orders" => []} if response["shipments"].blank?
          response = response["shipments"].first
          return get_order_on_demand(response["orderNumber"], true)
        end

        def log_on_demand_order_import(orderId, response, using_tracking_number)
          import_time = Time.now
          on_demand_logger.info("OrderNumber: #{orderId}")
          on_demand_logger.info("ImportTime: #{import_time}")
          on_demand_logger.info("Using Tracking Number: #{using_tracking_number}")
          on_demand_logger.info("Response: #{response}")
        end

        def on_demand_logger
          @costom_logger ||= Logger.new("#{Rails.root}/log/on_demand_import.log")
        end

        def get_tags_list
          tagslist_by_name = {}
          response = @service.query('/accounts/listtags', nil, "get")
          tags = response.parsed_response
          unless tags.blank?
            tags.each {|tag| tagslist_by_name[tag["name"]] = tag["tagId"]} rescue nil
          end
          return tagslist_by_name
        end

        def get_tag_id(tag)
          response = @service.query('/accounts/listtags', nil, "get")
          tags = response.parsed_response
          index = tags.empty? ? nil : tags.index { |x| x['name'] == tag }
          index.nil? ? -1 : tags[index]['tagId']
        end

        def get_orders_by_tag(tagId)
          response = { 'orders' => [] }
          unless tagId == -1
            %w(awaiting_payment awaiting_shipment shipped
               on_hold cancelled).each do |status|
              res = find_orders_by_tag_and_status(tagId, status)
              response['orders'] = response['orders'] + res unless res.nil?
            end
          end
          response
        end

        def find_orders_by_tag_and_status(tag_id, status)
          page_index = 1
          orders = []
          loop do
            response = @service.query("/orders/listbytag?orderStatus=#{status}&tagId=#{tag_id}&page=#{page_index}&pageSize=100", nil, "get")
            orders += response['orders'] unless response['orders'].nil?
            total_pages = response.parsed_response['pages']
            page_index += 1
            return orders if page_index > total_pages
          end
        end

        def remove_tag_from_order(order_id, tag_id)
          @service.query("/orders/removetag", { orderId: order_id, tagId: tag_id }, "post")
        end

        def add_tag_to_order(order_id, tag_id)
          @service.query("/orders/addtag", { orderId: order_id, tagId: tag_id }, "post")
        end

        def inspect
          "#<ShipStationRuby::Client:#{object_id}>"
        end

        private

        def fetch_orders(status, start_date)
          combined = { 'orders' => [] }
          page_index = 1
          loop do
            res = @service.query("/Orders/List?orderStatus=" \
              "#{status}&page=#{page_index}&pageSize=300#{start_date}", nil, "get")
            combined['orders'] = union(combined['orders'],
                                       res.parsed_response['orders'])
            page_index += 1
            return combined if res.parsed_response['orders'].length<500
          end
        end

        def handle_shipment_response(response, orderId)
          tracking_number = nil
          return tracking_number if response.parsed_response['shipments'].blank?
          response.parsed_response['shipments'].each do |s|
            next if s['orderId'].nil? || s['orderId'] != orderId
            tracking_number = s['trackingNumber']
            break
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

        def shipment_date_start(import_date_type, shipment_after)
          "&createDateStart=#{shipment_after}&createDateEnd=#{Date.today}"
        end

        def ss_format(start_date)
          #(start_date.beginning_of_day + Time.zone_offset('PDT').seconds).to_s
          #  .gsub(' UTC', '').gsub(' ', '%20')
          zone = ActiveSupport::TimeZone.new("Pacific Time (US & Canada)")
          time = start_date.to_datetime.in_time_zone(zone).strftime("%Y-%m-%d %H:%M:%S").gsub(" ", "%20")
        end

        def union(orders, second_set)
          orders += second_set unless second_set.length == 0
          orders
        end
      end
    end
  end
end
