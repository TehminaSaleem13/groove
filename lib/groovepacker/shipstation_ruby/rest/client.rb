# frozen_string_literal: true

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
          unless ord_placed_after.nil?
            start_date = order_date_start(
              date_type, ss_format(ord_placed_after)
            )
          end
          fetch_orders(status, start_date)
        end

        def get_orders_v2(status, ord_placed_after, order_import_range_days, date_type = 'created_at',
                          import_item = nil)
          unless ord_placed_after.nil?
            start_date = order_date_start(date_type,
                                          ord_placed_after.to_datetime.strftime('%Y-%m-%d %H:%M:%S').gsub(' ', '%20'), order_import_range_days)
          end
          fetch_orders(status, start_date, import_item)
        end

        def get_shipments(import_from, date_type = 'created_at', import_till = nil)
          shipments_after_last_import = []
          shipments_date = if import_till
                             shipment_dates(date_type, ss_format(import_from),
                                            ss_format(import_till))
                           else
                             shipment_dates(date_type,
                                            ss_format(import_from))
                           end
          page_index = 1
          while page_index
            response = @service.query("/shipments?page=#{page_index}&pageSize=200#{shipments_date}", nil, 'get')
            shipments_after_last_import = shipments_after_last_import.push(response['shipments']).flatten
            break if (begin
              response['shipments'].count
            rescue StandardError
              0
            end) < 200

            page_index += 1
          end
          Tenant.save_se_import_data("========Shipstation Shipments UTC: #{Time.current.utc} TZ: #{Time.current}",
                                     '==Import_From', import_from, '==Date_Type', date_type, '==Import Till', import_till, '==Shipments Date', shipments_date, '==Shipments After Last Import', shipments_after_last_import)
          shipments_after_last_import
        end

        def get_tracking_number(orderId)
          tracking_number = nil
          unless orderId.nil?
            order_number_param = '&orderId=' + orderId.to_s
            Rails.logger.info "Getting shipment with order Id: #{orderId}"
            response = @service.query('/Shipments/List?' \
              'page=1&pageSize=100' + CGI.escape(order_number_param), nil, 'get')
            tracking_number = handle_shipment_response(response, orderId)
          end
          tracking_number
        end

        def get_range_import_orders(start_date, end_date, type, order_import_range_days, order_status,
                                    import_item = nil)
          combined = { 'orders' => [] }
          if type == 'modified'
            created_date = (ActiveSupport::TimeZone['Pacific Time (US & Canada)'].parse(Time.zone.now.to_s) - order_import_range_days.days).strftime('%Y-%m-%d %H:%M:%S')
            date_val = order_import_range_days != 0 ? date_val = "&modifyDateStart=#{start_date}&modifyDateEnd=#{end_date}" : "&modifyDateStart=#{start_date}&modifyDateEnd=#{end_date}&orderStatus=#{order_status}"
          else
            date_val = "&orderDateStart=#{start_date}&orderDateEnd=#{end_date}"
          end
          page_index = 1
          loop do
            begin
              import_item&.touch
            rescue StandardError
              nil
            end
            res = @service.query(
              "/Orders?page=#{page_index}&pageSize=150#{date_val}&sortBy=OrderDate&sortDir=DESC&orderStatus=#{order_status}", nil, 'get'
            )
            if res.parsed_response.present?
              combined['orders'] =
                union(combined['orders'], res.parsed_response['orders'])
            end
            page_index += 1
            Tenant.save_se_import_data("========Shipstation Range Import UTC: #{Time.current.utc} TZ: #{Time.current}",
                                       '==Start Date', start_date, '==End Date', end_date, '==Type', type, '==Order Import Range Days', order_import_range_days, '==Order Status', order_status, '==Page Index', page_index, '==Date Value', date_val, '==Response', res)
            return combined if ((begin
              res.parsed_response['orders'].length
            rescue StandardError
              nil
            end) || 0) < 150
          end
        end

        def get_order_value(orderno)
          response = @service.query("/orders?orderNumber=#{orderno}", nil, 'get')
          response['orders'] = (response['orders'] || []).select { |ordr| ordr['orderNumber'] == orderno }
          Tenant.save_se_import_data("========Shipstation Order Value UTC: #{Time.current.utc} TZ: #{Time.current}",
                                     '==Order Number', orderno, '==Response', response)
          return response['orders'] if response['orders'].present?

          response = @service.query("/shipments?trackingNumber=#{orderno}", nil, 'get')
          return nil if response['shipments'].blank?

          shipment = response['shipments'].first
          get_order_value(shipment['orderNumber'])
        end

        def get_order(orderId)
          Rails.logger.info 'Getting orders with orderId: ' + orderId
          @service.query('/orders/' + orderId, nil, 'get')
        end

        def get_order_on_demand(orderno, import_item, using_tracking_number = false)
          response = @service.query("/orders?orderNumber=#{orderno}", nil, 'get')
          response = (response.class == String ? { 'orders' => [], 'total' => 0, 'page' => 1, 'pages' => 1 } : response)
          begin
            response['orders'] = (response['orders'] || []).select { |ordr| ordr['orderNumber'] == orderno }
          rescue StandardError
            response = { 'orders' => [], 'total' => 0, 'page' => 1, 'pages' => 1 }
          end
          log_on_demand_order_import(orderno, response, using_tracking_number)
          begin
            import_item.update(status: 'completed', current_increment_id: orderno,
                               updated_orders_import: response['orders'].count)
          rescue StandardError
            nil
          end
          Tenant.save_se_import_data(
            "========Shipstation Order On Demand UTC: #{Time.current.utc} TZ: #{Time.current}", '==Order Number', orderno, '==ImportItem', import_item, '==Using Tracking Number', using_tracking_number, '==Response', response
          )
          return response if using_tracking_number

          [response, get_shipments_by_orderno(orderno)]
        end

        def get_webhook_order(url, type, import_item)
          case type
          when "ORDER_NOTIFY", "ITEM_ORDER_NOTIFY"
            order_response = @service.query("/orders?#{url}", nil, 'get')
          when "SHIP_NOTIFY", "ITEM_SHIP_NOTIFY"
            shipment_response = @service.query("/shipments?#{url}", nil, 'get')
            order_number = shipment_response.dig('shipments', 0, 'orderNumber')
            order_response = @service.query("/orders?orderNumber=#{order_number}", nil, 'get')
          end

          import_item.update(
            status: 'completed',
            current_increment_id: order_response.dig('orders', 0, 'orderNumber'),
            updated_orders_import: order_response['orders']&.count
          ) rescue nil

          [order_response, shipment_response || []]
        end

        def update_product_bin_locations(products)
          response = {}
          products.each do |product|
            next unless product.primary_warehouse.try(:location_primary).present?

            product_hash = @service.query("/products/#{product.store_product_id}", {}, 'get')
            body = product_hash.to_h.merge('warehouseLocation' => product.primary_warehouse.location_primary).to_json
            begin
              response = @service.query("/products/#{product.store_product_id}", body, 'put')
            rescue StandardError => e
              puts e
            end
          end
          response
        end

        def pull_product_bin_locations(products)
          updated = false
          products.each do |product|
            product_hash = @service.query("/products/#{product.store_product_id}", {}, 'get')
            next unless product_hash['warehouseLocation'].present?

            product.primary_warehouse.update(location_primary: product_hash['warehouseLocation'])
            updated = true
          end
          updated
        end

        def create_label_for_order(data)
          response = {}
          default_ship_date = Time.current.in_time_zone('Pacific Time (US & Canada)').to_date
          data['shipDate'] ||= default_ship_date
          data['shipDate'] =
            data['shipDate'].to_date < default_ship_date ? default_ship_date.strftime('%a, %d %b %Y') : data['shipDate']
          data['testLabel'] =
            Tenant.find_by_name(Apartment::Tenant.current).try(:test_tenant_toggle) || Rails.env.development?
          begin
            response = @service.query('/orders/createlabelfororder', data, 'post', 'create_label')
          rescue StandardError => e
            puts e
          end
          response
        end

        def void_label(shipment_id)
          response = {}
          data['shipmentId'] = shipment_id
          begin
            response = @service.query('/shipments/voidlabel', data, 'post', 'create_label')
          rescue StandardError => e
            puts e
          end
          response
        end

        def get_ss_label_rates(data)
          response = {}
          begin
            response = @service.query('/shipments/getrates', data, 'post', 'create_label')
          rescue StandardError => e
            puts e
          end
          response
        end

        def list_carriers
          response = {}
          begin
            response = @service.query('/carriers', {}, 'get')
          rescue StandardError => e
            puts e
          end
          response
        end

        def list_services(carrier_code)
          response = {}
          begin
            response = @service.query("/carriers/listservices?carrierCode=#{carrier_code}", {}, 'get')
          rescue StandardError => e
            puts e
          end
          response
        end

        def list_packages(carrier_code)
          response = {}
          begin
            response = @service.query("/carriers/listpackages?carrierCode=#{carrier_code}", {}, 'get')
          rescue StandardError => e
            puts e
          end
          response
        end

        def get_order_by_tracking_number(tracking_number)
          on_demand_logger.info('********')
          response = @service.query("/shipments?trackingNumber=#{tracking_number}", nil, 'get')
          Tenant.save_se_import_data(
            "========Shipstation Order By Tracking Number UTC: #{Time.current.utc} TZ: #{Time.current}", '==Tracking Number', tracking_number, '==Response', response
          )
          return { 'orders' => [] } if response['shipments'].blank?

          shipment = response['shipments'].first
          [get_order_on_demand(shipment['orderNumber'], nil, true), response['shipments']]
        end

        def log_on_demand_order_import(_orderno, _response, _using_tracking_number)
          import_time = Time.current
        end

        def get_shipments_by_orderno(orderno)
          response = @service.query("/shipments?orderNumber=#{CGI.escape(orderno)}", nil, 'get')
          if response['shipments'].present?
            response['shipments'].select do |shipment|
              shipment['orderNumber'] == orderno
            end
          else
            # Fallback to Fulfillments
            return get_fulfillments_by_orderno(orderno)
          end
          Tenant.save_se_import_data(
            "========Shipstation Shipments By Order Number UTC: #{Time.current.utc} TZ: #{Time.current}", '==Order Number', orderno, '==Response', response
          )
          response['shipments']
        end

        def get_fulfillments_by_orderno(orderno)
          response = @service.query("/fulfillments?orderNumber=#{CGI.escape(orderno)}", nil, 'get')
          if response['fulfillments'].present?
            response['fulfillments'].select! do |fulfilment|
              fulfilment['orderNumber'] == orderno
            end
          end
          Tenant.save_se_import_data(
            "========Shipstation Fulfillments By Order Number UTC: #{Time.current.utc} TZ: #{Time.current}", '==Order Number', orderno, '==Response', response
          )
          response['fulfillments']
        end

        def get_shipments_by_order_id(order_id)
          response = @service.query("/shipments?orderId=#{CGI.escape(order_id)}", nil, 'get')
          response['shipments'].select { |shipment| shipment['orderId'] == order_id } if response['shipments'].present?
          Tenant.save_se_import_data(
            "========Shipstation Shipments By Order ID UTC: #{Time.current.utc} TZ: #{Time.current}", '==Order Id', order_id, '==Response', response
          )
          response['shipments'].map do |shipment|
            shipment['createDate'] =
              ActiveSupport::TimeZone['Pacific Time (US & Canada)'].parse(shipment['createDate']).to_time.in_time_zone
          end
          response['shipments']
        end

        def on_demand_logger
          @costom_logger ||= Logger.new("#{Rails.root.join("log/on_demand_import_#{Apartment::Tenant.current}.log")}")
        end

        def get_tags_list
          tagslist_by_name = {}
          response = @service.query('/accounts/listtags', nil, 'get')
          tags = response.parsed_response
          if tags.present?
            begin
              tags.each { |tag| tagslist_by_name[tag['name'].downcase] = tag['tagId'] }
            rescue StandardError
              nil
            end
          end
          tagslist_by_name
        end

        def get_all_tags_list
          tagslist_by_name = {}
          response = @service.query('/accounts/listtags', nil, 'get')
          response.parsed_response
        end

        def get_tag_id(tag)
          response = @service.query('/accounts/listtags', nil, 'get')
          tags = response.parsed_response
          index = tags.empty? ? nil : tags.index { |x| x['name'].casecmp(tag).zero? }
          index.nil? ? -1 : tags[index]['tagId']
        end

        def get_orders_by_tag(tagId, import_item = nil)
          response = { 'orders' => [] }
          unless tagId == -1
            %w[awaiting_shipment shipped pending_fulfillment awaiting_payment].each do |status|
              res = find_orders_by_tag_and_status(tagId, status, import_item)
              response['orders'] = response['orders'] + res unless res.nil?
            end
          end
          # response['orders'] = response['orders'].sort_by { |h| h["orderDate"].split('-') }.reverse rescue response['orders']
          response
        end

        def add_gp_scanned_tag(orderId)
          ss_tags_list = get_tags_list

          gp_scanned_tag_id = ss_tags_list['gp scanned'] || -1
          add_tag_to_order(orderId, gp_scanned_tag_id) if gp_scanned_tag_id != -1
        end

        def find_orders_by_tag_and_status(tag_id, status, import_item = nil)
          page_index = 1
          orders = []
          loop do
            begin
              import_item&.touch
            rescue StandardError
              nil
            end
            response = @service.query(
              "/orders/listbytag?orderStatus=#{status}&tagId=#{tag_id}&page=#{page_index}&pageSize=100", nil, 'get'
            )
            begin
              orders += response['orders'] unless response['orders'].nil?
            rescue StandardError
              nil
            end
            total_pages = begin
              response.parsed_response['pages']
            rescue StandardError
              nil
            end
            page_index += 1
            Tenant.save_se_import_data("========Shipstation Tag Import UTC: #{Time.current.utc} TZ: #{Time.current}",
                                       '==Status', status, '==Tag ID', tag_id, '==Response', response, '==Page_index', page_index)
            return orders if page_index > total_pages.to_i
          end
        end

        def check_gpready_awating_order(tag_id)
          response = @service.query("/orders/listbytag?orderStatus=awaiting_payment&tagId=#{tag_id}&page=1&pageSize=1",
                                    nil, 'get')
        end

        def remove_tag_from_order(order_id, tag_id)
          response = @service.query('/orders/removetag', { orderId: order_id, tagId: tag_id }, 'post')
          logs = { order_id:, tag_id:, response: response.to_h }
          Groovepacker::LogglyLogger.log(Apartment::Tenant.current, 'remove_tag_from_order', logs)
          response
        end

        def add_tag_to_order(order_id, tag_id)
          response = @service.query('/orders/addtag', { orderId: order_id, tagId: tag_id }, 'post')
          logs = { order_id:, tag_id:, response: }
          Groovepacker::LogglyLogger.log(Apartment::Tenant.current, 'ss_add_tag_to_order', logs)
          response
        end

        def inspect
          "#<ShipStationRuby::Client:#{object_id}>"
        end

        private

        def fetch_orders(status, start_date, import_item = nil)
          combined = { 'orders' => [] }
          page_index = 1
          loop do
            begin
              import_item&.touch
            rescue StandardError
              nil
            end
            res = @service.query('/Orders?orderStatus=' \
              "#{status}&page=#{page_index}&pageSize=150#{start_date}&sortBy=OrderDate&sortDir=DESC", nil, 'get')
            if res.parsed_response.present?
              combined['orders'] =
                union(combined['orders'], res.parsed_response['orders'])
            end
            page_index += 1
            Tenant.save_se_import_data("========Shipstation Order Import UTC: #{Time.current.utc} TZ: #{Time.current}",
                                       '==Status', status, '==Start Date', start_date, '==Res', res, '==Page_index', page_index)
            return combined if ((begin
              res.parsed_response['orders'].length
            rescue StandardError
              nil
            end) || 0) < 150
          end
        end

        def fetch_orders_count(status, start_date)
          page_index = 1
          res = @service.query('/Orders?orderStatus=' \
              "#{status}&page=#{page_index}&pageSize=1#{start_date}&sortBy=OrderDate&sortDir=DESC", nil, 'get')
          (begin
            res['total'].to_i
          rescue StandardError
            0
          end)
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
          elsif %w[modified_at].include?(import_date_type)
            predicate = 'modifyDateStart'
            if order_import_range_days.present?
              created_date = (ActiveSupport::TimeZone['Pacific Time (US & Canada)'].parse(Time.zone.now.to_s) - order_import_range_days.days).strftime('%Y-%m-%d %H:%M:%S')
            end
            if order_import_range_days.present? && order_import_range_days != 0
              "&#{predicate}=#{order_placed_after}&createDateStart=#{created_date.gsub(
                ' ', '%20'
              )}"
            else
              "&#{predicate}=#{order_placed_after}"
            end
          end
        end

        def shipment_dates(_import_date_type, shipment_after, shipment_till = nil)
          if shipment_till
            "&createDateStart=#{shipment_after}&createDateEnd=#{shipment_till}"
          else
            "&createDateStart=#{shipment_after}&createDateEnd=#{Date.today}"
          end
        end

        def ss_format(start_date)
          # (start_date.beginning_of_day + Time.zone_offset('PDT').seconds).to_s
          #  .gsub(' UTC', '').gsub(' ', '%20')
          zone = ActiveSupport::TimeZone.new('Pacific Time (US & Canada)')
          time = start_date.to_datetime.in_time_zone(zone).strftime('%Y-%m-%d %H:%M:%S').gsub(' ', '%20')
        end

        def union(orders, second_set)
          begin
            orders += second_set unless second_set.try(:length).to_i == 0
          rescue StandardError
            nil
          end
          orders
        end
      end
    end
  end
end
