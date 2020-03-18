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
          start_date = order_date_start(
            date_type, ss_format(ord_placed_after)) unless ord_placed_after.nil?
          fetch_orders(status, start_date)
        end

        def get_orders_v2(status, ord_placed_after, date_type = 'created_at', order_import_range_days)
          start_date = order_date_start(date_type, ord_placed_after.to_datetime.strftime("%Y-%m-%d %H:%M:%S").gsub(' ', '%20'), order_import_range_days) unless ord_placed_after.nil?
          fetch_orders(status, start_date)
        end

        def get_shipments(import_from, date_type = 'created_at', import_till = nil)
          shipments_after_last_import = []
          shipments_date = import_till ? shipment_dates(date_type, ss_format(import_from), ss_format(import_till)) : shipment_dates(date_type, ss_format(import_from))
          page_index=1
          while page_index
            response = @service.query("/shipments?page=#{page_index}&pageSize=200#{shipments_date}", nil, "get")
            shipments_after_last_import = shipments_after_last_import.push(response["shipments"]).flatten
            break if (response["shipments"].count rescue 0)<200
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

        def get_range_import_orders(start_date, end_date, type, order_import_range_days, order_status)
          combined = { 'orders' => [] }
          if type == "modified"
            created_date = (ActiveSupport::TimeZone["Pacific Time (US & Canada)"].parse(Time.zone.now.to_s) - order_import_range_days.days).strftime('%Y-%m-%d %H:%M:%S')
            date_val = order_import_range_days != 0 ? date_val = "&modifyDateStart=#{start_date}&modifyDateEnd=#{end_date}&createDateStart=#{created_date.gsub(' ', '%20')}" : "&modifyDateStart=#{start_date}&modifyDateEnd=#{end_date}&orderStatus=#{order_status}"
          else
            date_val = "&orderDateStart=#{start_date}&orderDateEnd=#{end_date}"
          end
          page_index = 1
          loop do
            res = @service.query("/Orders?page=#{page_index}&pageSize=150#{date_val}&sortBy=OrderDate&sortDir=DESC&orderStatus=#{order_status}", nil, "get")
            combined['orders'] = union(combined['orders'], res.parsed_response['orders']) if res.parsed_response.present?
            page_index += 1
            return combined if ((res.parsed_response['orders'].length rescue nil) || 0)<150
          end
        end

        def get_order_value(orderno)
          response = @service.query("/orders?orderNumber=#{orderno}", nil, "get")
          response["orders"] = (response["orders"] || []).select {|ordr| ordr["orderNumber"]==orderno }
          if response["orders"].present?
            return response["orders"]
          else
            response = @service.query("/shipments?trackingNumber=#{orderno}", nil, "get")
            return nil if response["shipments"].blank?
            shipment = response["shipments"].first
            get_order_value(shipment["orderNumber"])
          end
        end

        def get_order(orderId)
          Rails.logger.info 'Getting orders with orderId: ' + orderId
          @service.query("/orders/" + orderId, nil, "get")
        end

        def get_order_on_demand(orderno, import_item, using_tracking_number=false)
          response = @service.query("/orders?orderNumber=#{orderno}", nil, "get")
          response = (response.class == String ? {"orders"=>[], "total"=>0, "page"=>1, "pages"=>1} : response)
          begin
            response["orders"] = (response["orders"] || []).select {|ordr| ordr["orderNumber"]==orderno }
          rescue
            response = {"orders"=>[], "total"=>0, "page"=>1, "pages"=>1}
          end
          log_on_demand_order_import(orderno, response, using_tracking_number)
          import_item.update_attributes(:status => "completed",:current_increment_id => orderno, :updated_orders_import => response["orders"].count) rescue nil
          if using_tracking_number
            return response
          else
            return response, get_shipments_by_orderno(orderno)
          end
        end

        def get_order_by_tracking_number(tracking_number)
          on_demand_logger.info("********")
          response = @service.query("/shipments?trackingNumber=#{tracking_number}", nil, "get")
          return {"orders" => []} if response["shipments"].blank?
          shipment = response["shipments"].first
          return get_order_on_demand(shipment["orderNumber"], nil, true), response["shipments"]
        end

        def log_on_demand_order_import(orderno, response, using_tracking_number)
          import_time = Time.now
        end

        def get_shipments_by_orderno(orderno)
          response = @service.query("/shipments?orderNumber=#{URI.encode(orderno)}", nil, "get")
          response["shipments"].select {|shipment| shipment["orderNumber"] == orderno}
        end

        def on_demand_logger
          @costom_logger ||= Logger.new("#{Rails.root}/log/on_demand_import_#{Apartment::Tenant.current}.log")
        end

        def get_tags_list
          tagslist_by_name = {}
          response = @service.query('/accounts/listtags', nil, "get")
          tags = response.parsed_response
          unless tags.blank?
            tags.each {|tag| tagslist_by_name[tag["name"].downcase] = tag["tagId"]} rescue nil
          end
          return tagslist_by_name
        end

        def get_tag_id(tag)
          response = @service.query('/accounts/listtags', nil, "get")
          tags = response.parsed_response
          index = tags.empty? ? nil : tags.index { |x| x['name'].downcase == tag.downcase }
          index.nil? ? -1 : tags[index]['tagId']
        end

        def get_orders_by_tag(tagId)
          response = { 'orders' => [] }
          unless tagId == -1
            %w(awaiting_shipment shipped pending_fulfillment awaiting_payment).each do |status|
              res = find_orders_by_tag_and_status(tagId, status)
              response['orders'] = response['orders'] + res unless res.nil?
            end
          end
          # response['orders'] = response['orders'].sort_by { |h| h["orderDate"].split('-') }.reverse rescue response['orders']
          response
        end



        def find_orders_by_tag_and_status(tag_id, status)
          page_index = 1
          orders = []
          loop do
            response = @service.query("/orders/listbytag?orderStatus=#{status}&tagId=#{tag_id}&page=#{page_index}&pageSize=100", nil, "get")
            orders += response['orders'] unless response['orders'].nil? rescue nil
            total_pages = response.parsed_response['pages'] rescue nil
            page_index += 1
            return orders if page_index > total_pages.to_i
          end
        end

        def check_gpready_awating_order(tag_id)
          response = @service.query("/orders/listbytag?orderStatus=awaiting_payment&tagId=#{tag_id}&page=1&pageSize=1", nil, "get")
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
            res = @service.query("/Orders?orderStatus=" \
              "#{status}&page=#{page_index}&pageSize=150#{start_date}&sortBy=OrderDate&sortDir=DESC", nil, "get")
            combined['orders'] = union(combined['orders'], res.parsed_response['orders']) if res.parsed_response.present?
            page_index += 1
            return combined if ((res.parsed_response['orders'].length rescue nil) || 0)<150
          end
        end

        def fetch_orders_count(status, start_date)
          page_index = 1
          res = @service.query("/Orders?orderStatus=" \
              "#{status}&page=#{page_index}&pageSize=1#{start_date}&sortBy=OrderDate&sortDir=DESC", nil, "get")
          return (res["total"].to_i rescue 0)
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

        def order_date_start(import_date_type, order_placed_after, order_import_range_days = nil)
          if import_date_type == 'created_at'
            "&orderDateStart=#{order_placed_after}"
          elsif %w(modified_at).include?(import_date_type)
            predicate = 'modifyDateStart'
            created_date = (ActiveSupport::TimeZone["Pacific Time (US & Canada)"].parse(Time.zone.now.to_s) - order_import_range_days.days).strftime('%Y-%m-%d %H:%M:%S') if order_import_range_days.present?
            order_import_range_days.present? && order_import_range_days != 0 ? "&#{predicate}=#{order_placed_after}&createDateStart=#{created_date.gsub(' ', '%20')}" : "&#{predicate}=#{order_placed_after}"
          end
        end

        def shipment_dates(import_date_type, shipment_after, shipment_till = nil)
          if shipment_till
            "&createDateStart=#{shipment_after}&createDateEnd=#{shipment_till}"
          else
            "&createDateStart=#{shipment_after}&createDateEnd=#{Date.today}"
          end
        end

        def ss_format(start_date)
          #(start_date.beginning_of_day + Time.zone_offset('PDT').seconds).to_s
          #  .gsub(' UTC', '').gsub(' ', '%20')
          zone = ActiveSupport::TimeZone.new("Pacific Time (US & Canada)")
          time = start_date.to_datetime.in_time_zone(zone).strftime("%Y-%m-%d %H:%M:%S").gsub(" ", "%20")
        end

        def union(orders, second_set)
          orders += second_set unless second_set.try(:length).to_i == 0 rescue nil
          orders
        end
      end
    end
  end
end
