# frozen_string_literal: true

module Groovepacker
  module Stores
    module Importers
      module ShipstationRest
        include ProductsHelper
        class OrdersImporterNew < Groovepacker::Stores::Importers::Importer
          attr_accessor :importing_time, :quick_importing_time, :import_from, :import_date_type
          include ProductsHelper

          def import
            init_common_objects
            @import_item.update(updated_orders_import: 0)
            set_import_date_and_type
            if statuses.empty? && gp_ready_tag_id == -1
              set_status_and_msg_for_skipping_import
            else
              initialize_orders_import
            end
            update_orders_status
            destroy_nil_import_items
            ids = begin
                    OrderItemKitProduct.select('MIN(id) as id').group('product_kit_skus_id, order_item_id').collect(&:id)
                  rescue StandardError
                    nil
                  end
            OrderItemKitProduct.where('id NOT IN (?)', ids).destroy_all
            @result
          end

          def initialize_orders_import
            Tenant.save_se_import_data("========Shipstation Regular Import Started UTC: #{Time.current.utc} TZ: #{Time.current}")
            begin
              OrderImportSummary.top_summary.emit_data_to_user(true)
            rescue StandardError
              nil
            end
            return @result unless @import_item.present?

            @import_item.update_column(:importer_id, @worker_id)
            response = get_orders_response
            response['orders'] = begin
                                   response['orders'].sort_by { |h| h['modifyDate'].split('-') }
                                 rescue StandardError
                                   response['orders']
                                 end
            # response["orders"] = response["orders"].sort {|vn1, vn2| vn2["orderDate"] <=> vn1["orderDate"]} rescue response["orders"]
            return @result if response['orders'].blank?

            shipments_response = should_fetch_shipments? ? @client.get_shipments(import_from - 1.days) : []
            @result[:total_imported] = response['orders'].length
            initialize_import_item
            @regular_import_triggered = true if @result[:status] && @import_item.import_type == 'quick'
            Groovepacker::Stores::Importers::LogglyLog.log_orders_response(response['orders'], @store, @import_item, shipments_response) if current_tenant_object&.loggly_shipstation_imports

            import_orders_from_response(response, shipments_response)
            send_sku_not_found_report_during_order_import
            destroy_nil_import_items
            Tenant.save_se_import_data("========Shipstation Regular Import Finished UTC: #{Time.current.utc} TZ: #{Time.current}", '==Import Item', @import_item)
          end

          def range_import(start_date, end_date, type, user_id)
            init_common_objects
            initialize_import_item
            start_date = type == 'created' ? get_gp_time_in_pst(start_date) : Time.zone.parse(start_date).strftime('%Y-%m-%d %H:%M:%S')
            end_date = type == 'created' ? get_gp_time_in_pst(end_date) : Time.zone.parse(end_date).strftime('%Y-%m-%d %H:%M:%S')
            init_order_import_summary(user_id)
            Tenant.save_se_import_data("========Shipstation Range Import Started UTC: #{Time.current.utc} TZ: #{Time.current}", '==Start Date', start_date, '==End Date', end_date, '==Type', type, '==User ID', user_id)
            response = fetch_order_response_from_ss(start_date.gsub(' ', '%20'), end_date.gsub(' ', '%20'), type, @import_item)
            @import_item.update(to_import: response['orders'].count)
            shipments_response = should_fetch_shipments? ? @client.get_shipments(start_date, nil, end_date) : []
            import_orders_from_response(response, shipments_response)
            send_sku_not_found_report_during_order_import
            update_order_import_summary
            Tenant.save_se_import_data("========Shipstation Range Import Finished UTC: #{Time.current.utc} TZ: #{Time.current}", '==Import Item', @import_item)
          end

          def quick_fix_import(import_date, order_id, user_id)
            init_common_objects
            initialize_import_item
            check_import_item
            import_date = Time.zone.parse(import_date) + Time.zone.utc_offset
            import_date = DateTime.parse(import_date.to_s)
            quick_fix_range = get_quick_fix_range(import_date, order_id)
            start_date = quick_fix_range[:start_date].strftime('%Y-%m-%d %H:%M:%S')
            end_date = quick_fix_range[:end_date].strftime('%Y-%m-%d %H:%M:%S')
            init_order_import_summary(user_id)
            Tenant.save_se_import_data("========Shipstation QF Import Started UTC: #{Time.current.utc} TZ: #{Time.current}", '==Start Date', start_date, '==End Date', end_date, '==Import Date', import_date, '==Order Id', order_id, '==User ID', user_id)
            response = fetch_order_response_from_ss(start_date.gsub(' ', '%20'), end_date.gsub(' ', '%20'), 'modified', @import_item)
            @import_item.update(to_import: response['orders'].count)
            shipments_response = should_fetch_shipments? ? @client.get_shipments(start_date, nil, end_date) : []
            import_orders_from_response(response, shipments_response)
            update_order_import_summary
            Tenant.save_se_import_data("========Shipstation QF Import Finished UTC: #{Time.current.utc} TZ: #{Time.current}", '==Import Item', @import_item)
          end

          def init_order_import_summary(user_id)
            OrderImportSummary.where("status != 'in_progress' OR status = 'completed'").destroy_all
            ImportItem.where(store_id: @store.id).where("status = 'cancelled' OR status = 'completed'").destroy_all
            @import_summary = OrderImportSummary.top_summary
            @import_summary ||= OrderImportSummary.create(user_id: user_id, status: 'not_started', display_summary: false)
            @import_item.update(order_import_summary_id: @import_summary.id, status: 'not_started')
            @range_or_quickfix_started = true
            @import_summary.emit_data_to_user(true)
          end

          def update_order_import_summary
            @import_item.update(status: 'completed') if @import_item.reload.status != 'cancelled'
            destroy_nil_import_items
            @import_summary.update(status: 'completed') if OrderImportSummary.joins(:import_items).where("import_items.status = 'in_progress' OR import_items.status = 'not_started'").blank?
            @import_summary.emit_data_to_user(true)
          end

          def check_import_item
            @import_item.reload
          rescue StandardError
            @import_item = ImportItem.create(store_id: @import_item.store_id, status: 'not_started', updated_orders_import: 0)
          end

          def get_quick_fix_range(import_date, order_id)
            quick_fix_range = {}
            last_imported_order = Order.find(order_id)
            store_orders = Order.where('store_id = ? AND id != ?', @store.id, order_id)
            if store_orders.blank? || store_orders.where('last_modified > ?', last_imported_order.last_modified).blank?
              notify_and_reset_lro(store_orders)
              # Rule #1 - If there are no orders in our DB (other than the order provided to the troubleshooter, ie. the QF Order which gets automatically imported) when the QF import is run, then delete the LRO timestamp and run a regular import. - A 24 hour import range will be run rather than the usual QF range.

              # Rule #2- If the OSLMT of the QF order is newer/more recent than that of any OSLMT in DB, then run a regular import
              quick_fix_range[:start_date] = get_qf_range_start_date
              quick_fix_range[:end_date] = convert_to_pst(Time.zone.now)
            elsif store_orders.where('last_modified < ?', last_imported_order.last_modified).blank?
              # Rule #3- If the OSLMT of the QF order is Older than any OSLMT saved in our DB , and a more recent order does exist, then start the import range 6 hours before the OSLMT of the QF order and end the range 6 hours after the OSLMT of the QF order. (12 hours with the OSLMT in the middle)
              quick_fix_range[:start_date] = last_imported_order.last_modified - 6.hours
              quick_fix_range[:end_date] = last_imported_order.last_modified + 6.hours
            else
              quick_fix_range[:start_date] = get_closest_date(order_id, import_date, '<')
              quick_fix_range[:end_date] = get_closest_date(order_id, import_date, '>')
            end
            quick_fix_range
          end

          def notify_and_reset_lro(store_orders)
            @regular_import_triggered = true
            Order.emit_notification_ondemand_quickfix(@notify_user_id) if @notify_regular_import
            # @credential.update(quick_import_last_modified_v2: nil) if store_orders.blank? && @store.regular_import_v2
            @credential.update(quick_import_last_modified_v2: nil) if store_orders.blank?
          end

          def get_qf_range_start_date
            # if @store.regular_import_v2 && @credential.quick_import_last_modified_v2
            #   @credential.quick_import_last_modified_v2
            # elsif @store.regular_import_v2 == false && @credential.quick_import_last_modified
            #   @credential.quick_import_last_modified - 8.hours
            # else
            #   convert_to_pst(1.day.ago)
            # end
            @credential.quick_import_last_modified_v2 || convert_to_pst(1.day.ago)
          end

          def get_gp_time_in_pst(time)
            gp_to_utc = convert_time_from_gp(Time.zone.parse(time).utc)
            convert_to_pst(gp_to_utc).strftime('%Y-%m-%d %H:%M:%S')
          end

          def convert_time_from_gp(time)
            time_zone = GeneralSetting.last.time_zone.to_i
            (time - time_zone).strftime('%Y-%m-%d %H:%M:%S')
          end

          def convert_to_pst(time)
            zone = ActiveSupport::TimeZone.new('Pacific Time (US & Canada)')
            time.to_datetime.in_time_zone(zone)
          end

          def get_closest_date(order_id, date, comparison_operator)
            altered_date = comparison_operator == '<' ? date - 1.minute : date + 1.minute
            sort_order = comparison_operator == '<' ? 'asc' : 'desc'

            closest_date = Order.select('last_modified').where('store_id = ? AND id != ?', @store.id, order_id).where("last_modified #{comparison_operator} ?", altered_date).order("last_modified #{sort_order}").last.try(:last_modified)
            return closest_date if closest_date.present?

            date
          end

          def import_single_order(order_no, user_id, on_demand_quickfix, controller)
            @import_single_order = true
            @ondemand_user_name = ondemand_user(user_id)
            init_common_objects
            initialize_import_item
            @scan_settings = ScanPackSetting.last
            response, shipments_response = @client.get_order_on_demand(order_no, @import_item)
            response, shipments_response = @client.get_order_by_tracking_number(order_no) if response['orders'].blank? && (@scan_settings.scan_by_shipping_label || @scan_settings.scan_by_packing_slip_or_shipping_label)
            import_orders_from_response(response, shipments_response)
            send_sku_not_found_report_during_order_import
            Order.emit_data_for_on_demand_import_v2(response, order_no, user_id) if controller != 'stores'
            # od_tz = @import_item.created_at + GeneralSetting.last.time_zone.to_i
            od_tz = @import_item.created_at
            od_utc = @import_item.created_at.utc
            status_set_in_gp = shipstation_order_import_status
            if response['orders'].blank?
              log = { 'Tenant' => Apartment::Tenant.current.to_s, 'Order number' => order_no.to_s, 'Order Status Settings' => status_set_in_gp.to_s, 'Order Date Settings' => "#{@credential.regular_import_range} days", 'Timestamp of the OD import (in tenants TZ)' => od_tz.to_s, 'Timestamp of the OD import (UTC)' => od_utc.to_s, 'Type' => 'import failure' }
            else
              order_in_gp = find_order_in_gp(order_no)
              log = { 'Tenant' => Apartment::Tenant.current.to_s, 'Order number' => order_no.to_s, 'Order Create Date' => order_in_gp.try(:created_at).to_s, 'Order Modified Date' => order_in_gp.try(:updated_at).to_s, 'Order Status (the status in the OrderManager)' => ((begin
                                                                                                                                                                                                                                                                                 response['orders'].first['orderStatus']
                                                                                                                                                                                                                                                                              rescue StandardError
                                                                                                                                                                                                                                                                                nil
                                                                                                                                                                                                                                                                               end)).to_s, 'Order Status Settings' => status_set_in_gp.to_s, 'Order Date Settings' => "#{@credential.regular_import_range} days", 'Timestamp of the OD import (in tenants TZ)' => od_tz.to_s, 'Timestamp of the OD import (UTC)' => od_utc.to_s, 'Type' => 'import success' }
            end
            create_import_summary(log)
            @import_item.destroy
            destroy_nil_import_items
            no_ongoing_imports = ImportItem.where("status = 'not_started' OR status = 'in_progress' AND store_id = #{@store.id}").blank?
            init_qf_after_on_demand(response['orders'][0]['modifyDate'], user_id, order_in_gp.id) if on_demand_quickfix && response['orders'].present? && @store.quick_fix && no_ongoing_imports && (begin
                                                                                                                                                                                                       order_in_gp
                                                                                                                                                                                                     rescue StandardError
                                                                                                                                                                                                       nil
                                                                                                                                                                                                     end)
          end

          def process_webhook_import_order(url)
            @import_webhook_order = true
            init_common_objects
            initialize_import_item
            @scan_settings = ScanPackSetting.last
            response = @client.get_webhook_order(url, @import_item)
            import_orders_from_response(response, [])
            @import_item.destroy
            destroy_nil_import_items
          end

          def import_orders_from_response(response, shipments_response)
            # check_or_assign_import_item
            response['orders'] = response['orders'].sort_by { |order| Time.zone.parse(order['modifyDate']) } if response['orders'].present?
            @store.shipstation_rest_credential.update(bulk_import: false)
            @bulk_ss_import = 0
            @is_download_image = @store.shipstation_rest_credential.download_ss_image
            emit_data_for_range_or_quickfix

            response['orders'].each do |order|
              import_item_fix
              ImportItem.where(store_id: @store.id).where.not(status: %w[failed completed]).order(:created_at).drop(1).each { |item| item.update_column(:status, 'cancelled') }

              break if import_should_be_cancelled

              begin
                update_import_item_and_import_order(order, shipments_response)
                @credential.update(quick_import_last_modified_v2: Time.zone.parse(order['modifyDate'])) if @regular_import_triggered
              rescue Exception => e
                Rollbar.error(e, e.message, Apartment::Tenant.current)
              end
              # break if Rails.env == "test"
              # sleep 0.3
            end
            cred = @store.shipstation_rest_credential
            cred.bulk_import = @import_item.status == 'in_progress' && @bulk_ss_import >= 25 ? true : false
            cred.download_ss_image = false
            cred.save
          end

          def import_order_form_response(shipstation_order, order, shipments_response)
            if shipstation_order.present? && !shipstation_order.persisted? && order['orderStatus'] != 'cancelled'
              import_order(shipstation_order, order)
              shipstation_order = Order.find_by_id(shipstation_order.id) if shipstation_order.frozen?
              shipstation_order.tracking_num = begin
                                                 order_tracking_number(order, shipments_response)
                                               rescue StandardError
                                                 nil
                                               end
              shipstation_order.importer_id = @worker_id
              shipstation_order.import_item_id = begin
                                                   @import_item.id
                                                 rescue StandardError
                                                   nil
                                                 end
              import_order_items(shipstation_order, order)

              return unless shipstation_order.order_items.present?
              return unless shipstation_order.save

              check_for_replace_product ? update_order_activity_log_for_gp_coupon(shipstation_order, order) : update_order_activity_log(shipstation_order, order)
              remove_gp_tags_from_ss(order)
            else
              delete_order_and_log_event(shipstation_order) if shipstation_order.persisted? && order['orderStatus'] == 'cancelled'
              @import_item.update(updated_orders_import: @import_item.updated_orders_import + 1)
              @result[:previous_imported] = @result[:previous_imported] + 1
            end
            shipstation_order
          end

          def import_order(shipstation_order, order)
            tenant = Apartment::Tenant.current
            tenant = Tenant.where(name: tenant.to_s).first
            order['customerEmail'] = nil if tenant.gdpr_shipstation
            shipstation_order.attributes = {  increment_id: order['orderNumber'], store_order_id: order['orderId'],
                                              order_placed_time: ActiveSupport::TimeZone['Pacific Time (US & Canada)'].parse(order['orderDate']).to_time, email: order['customerEmail'],
                                              shipping_amount: order['shippingAmount'], order_total: order['amountPaid'] }
            shipstation_order.build_shipstation_label_data(content: order.slice('orderId', 'carrierCode', 'serviceCode', 'packageCode', 'confirmation', 'shipDate', 'weight', 'dimensions', 'insuranceOptions', 'internationalOptions', 'advancedOptions'))
            shipstation_order.last_modified = ActiveSupport::TimeZone['Pacific Time (US & Canada)'].parse(order['modifyDate']).to_time
            shipstation_order = init_shipping_address(shipstation_order, order) unless tenant.gdpr_shipstation
            shipstation_order = import_notes(shipstation_order, order)
            shipstation_order.weight_oz = begin
                                            order['weight']['value']
                                          rescue StandardError
                                            nil
                                          end
          end

          def import_order_items(shipstation_order, order)
            return if order['items'].nil?
            @import_item.update(current_order_items: order['items'].length, current_order_imported_item: 0)
            
            order['items'].each do |item|
              if check_shopify_as_a_product_source
                product = Product.joins(:product_skus).find_by(product_skus: { sku: item['sku'] }) || fetch_and_import_shopify_product(item['sku'], item, shipstation_order.increment_id)
                next unless product
              else
                next if remove_coupon_codes?(item)

                product = product_importer_client.find_or_create_product(item)
                create_product_image
              end
              import_order_item(item, shipstation_order, product)
              @import_item.current_order_imported_item = @import_item.current_order_imported_item + 1
            end
            @import_item.save
          end

          def remove_coupon_codes?(item)
            @credential.import_discounts_option && item['adjustment'] && @credential.set_coupons_to_intangible
          end

          def create_product_image
            if @is_download_image
              images = product.product_images
              product.product_images.create(image: item['imageUrl']) if item['imageUrl'].present? && images.blank?
            end
          end

          def import_order_item(item, shipstation_order, product)
            order_item = shipstation_order.order_items.build(product_id: product.id)
            order_item.qty = item['quantity']
            order_item.price = item['unitPrice']
            order_item.row_total = item['unitPrice'].to_f * item['quantity'].to_f
          end

          def verify_awaiting_tags
            init_common_objects
            @client.check_gpready_awating_order(gp_ready_tag_id)
          end

          private

          def statuses
            @statuses ||= @credential.get_active_statuses
          end

          def set_import_date_and_type
            case @import_item.import_type
            when 'deep'
              self.import_from = DateTime.now.in_time_zone - (begin
                                                                  @import_item.days.to_i.days
                                                              rescue StandardError
                                                                1.days
                                                                end)
            when 'regular', 'quick'
              set_regular_quick_import_date
            when 'tagged'
              @import_item.update_attribute(:import_type, 'tagged')
              self.import_from = DateTime.now.in_time_zone - 1.weeks
            else
              set_import_date_from_store_cred
            end
            set_import_date_type
          end

          def set_regular_quick_import_date
            @import_item.update_attribute(:import_type, 'quick')
            quick_import_date = @credential.quick_import_last_modified_v2
            quick_import_date += 1.second if @credential.bulk_import && quick_import_date
            Order.emit_notification_for_default_import_date(@import_item.order_import_summary&.user_id, @store, nil, 1) if quick_import_date.nil?
            self.import_from = quick_import_date || (DateTime.now.in_time_zone - 1.days)
          end

          def set_import_date_from_store_cred
            @import_item.update_attribute(:import_type, 'regular')
            last_imported_at = @credential.last_imported_at
            self.import_from = last_imported_at.blank? ? DateTime.now.in_time_zone - 1.weeks : last_imported_at - @credential.regular_import_range.days
          end

          def set_import_date_type
            date_types = { 'deep' => 'modified_at', 'quick' => 'modified_at' }
            self.import_date_type = date_types[@import_item.import_type] || 'created_at'
          end

          def ss_tags_list
            @ss_tags_list ||= @client.get_tags_list
          end

          def gp_ready_tag_id
            @gp_ready_tag_id ||= ss_tags_list[@credential.gp_ready_tag_name.downcase] || -1
          end

          def gp_imported_tag_id
            @gp_imported_tag_id ||= ss_tags_list[@credential.gp_imported_tag_name.downcase] || -1
          end

          def gp_scanned_tag_id
            @gp_scanned_tag_id ||= ss_tags_list[@credential.gp_scanned_tag_name.downcase] || -1
          end

          def init_shipping_address(shipstation_order, order)
            return shipstation_order if order['shipTo'].blank?

            address = order['shipTo']
            split_name = begin
                             address['name'].split(' ')
                         rescue StandardError
                           ' '
                           end
            shipstation_order.attributes = {
              lastname: split_name.pop, firstname: split_name.join(' '),
              address_1: address['street1'], address_2: address['street2'],
              city: address['city'], state: address['state'],
              postcode: address['postalCode'], country: address['country']
            }
            shipstation_order
          end

          def import_notes(shipstation_order, order)
            shipstation_order.notes_internal = order['internalNotes'] if @credential.shall_import_internal_notes
            shipstation_order.customer_comments = order['customerNotes'] if @credential.shall_import_customer_notes
            shipstation_order
          end

          def get_orders_response
            response = { 'orders' => nil }
            Order.emit_notification_all_status_disabled(@import_item.order_import_summary.user_id) if statuses.blank? && !@credential.tag_import_option && @import_item.import_type != 'tagged'
            response = fetch_response_from_shipstation(response)
            if %w[lairdsuperfood gunmagwarehouse].include?(Apartment::Tenant.current)
              on_demand_logger = Logger.new("#{Rails.root}/log/shipstation_tag_order_import_#{Apartment::Tenant.current}.log")
              on_demand_logger.info('=========================================')
              begin
                on_demand_logger.info(response['orders'].map { |a| a['orderId'] }.join(', '))
              rescue StandardError
                on_demand_logger.info('')
              end
            end
            response
          end

          def fetch_response_from_shipstation(response)
            response = fetch_orders_if_import_type_is_not_tagged(response)
            response = fetch_tagged_orders(response) if @credential.tag_import_option || @import_item.import_type == 'tagged'
            response
          end

          def emit_data_for_range_or_quickfix
            if @range_or_quickfix_started
              @import_item.update(status: 'in_progress')
              @import_summary.emit_data_to_user(true)
            end
          end

          def shipstation_order_import_status
            status_set_in_gp = []
            status_set_in_gp << 'Awaiting Shipment' if @credential.shall_import_awaiting_shipment
            status_set_in_gp << 'Pending Fulfillment' if @credential.shall_import_pending_fulfillment
            status_set_in_gp << 'Shipped' if @credential.shall_import_shipped
            status_set_in_gp
          end

          def update_import_item_and_import_order(order, shipments_response)
            return if skip_the_order?(shipments_response, order)

            @import_item.update(current_increment_id: order['orderNumber'], current_order_items: -1, current_order_imported_item: -1)
            # If a large number of orders are imported into SS at the same time via CSV, their OSLMT will be the same. During each regular import, we count how many consecutive orders have had the same timestamp. While this count is => to 25 we will set a flag to 1 If a non-matching OSLMT is imported or if the import fails in any way, the flag is reset to 0. When each import is run we will check this flag. If it is set to 1 at the start of the import we will adjust our LRO timestamp forward by 1 second and set the flag back to 0 ##### @bulk_ss_import #####
            Order.last.try(:last_modified).to_s == Time.zone.parse(order['modifyDate']).to_s ? @bulk_ss_import += 1 : @bulk_ss_import = 0
            return if check_order_is_cancelled(order)
            shipstation_order = find_or_init_new_order(order)

            return unless import_order_form_response(shipstation_order, order, shipments_response)

            if order['tagIds'].present?
              tags_list  = @client.get_all_tags_list

              order['tagIds'].each do |tag_id|
                tag = tags_list.select { |tag| tag["tagId"] == tag_id }
                shipstation_order.add_tag(tag.first) if tag.present?
              end
            end
          rescue StandardError => e
            begin
                log_import_error(e)
            rescue StandardError
              nil
              end
            begin
              @import_item.update(updated_orders_import: @import_item.updated_orders_import + 1)
            rescue StandardError
              nil
            end
            @result[:previous_imported] += begin
                                               1
                                           rescue StandardError
                                             nil
                                             end
          end

          def fetch_orders_if_import_type_is_not_tagged(response)
            return response unless @import_item.import_type != 'tagged'

            statuses.each do |status|
              status_response = @client.get_orders_v2(status, import_from, @credential.order_import_range_days, import_date_type, @import_item)
              response = get_orders_from_union(response, status_response)
            end
            response
          end

          def fetch_tagged_orders(response)
            return response unless gp_ready_tag_id != -1

            tagged_response = @client.get_orders_by_tag(gp_ready_tag_id, @import_item)
            # perform union of orders
            if Apartment::Tenant.current == 'rabbitair' && tagged_response['orders'].present?
              value_1 = []
              tagged_response['orders'].each do |order|
                value_1 << order['orderNumber']
              end
              ImportMailer.check_old_orders(Apartment::Tenant.current, value_1)
            end
            response = get_orders_from_union(response, tagged_response)
            response
          end

          def get_orders_from_union(response, tagged_or_status_response)
            response['orders'] = response['orders'].blank? ? tagged_or_status_response['orders'] : (response['orders'] | tagged_or_status_response['orders'])
            response
          end

          def set_status_and_msg_for_skipping_import
            @result[:status] = false
            @result[:messages].push(
              'All import statuses disabled and no GP Ready tags found. Import skipped.'
            )
            @import_item.message = 'All import statuses disabled and no GP Ready tags found. Import skipped.'
            @import_item.save
          end

          def check_order_is_cancelled(order)
            shipstation_order = search_order_in_db(order['orderNumber'], order['orderId'])
            handle_cancelled_order(shipstation_order)
          end

          def find_or_init_new_order(order)
            shipstation_order = search_order_in_db(order['orderNumber'], order['orderId'])
            @order_to_update = shipstation_order.present?
            return if shipstation_order.present? && (shipstation_order.status == 'scanned' || shipstation_order.order_items.map(&:scanned_status).include?('partially_scanned') || shipstation_order.order_items.map(&:scanned_status).include?('scanned'))

            if @import_item.import_type == 'quick' && shipstation_order
              shipstation_order.destroy
              shipstation_order = nil
            end
            init_new_order_if_required(shipstation_order, order)
          end

          def init_new_order_if_required(shipstation_order, order)
            if shipstation_order.blank?
              shipstation_order = Order.new(store_id: @store.id)
            elsif (order['tagIds'] || []).include?(gp_ready_tag_id)
              # in order to adjust inventory on deletion of order assign order status as 'cancelled'
              shipstation_order.status = 'cancelled'
              shipstation_order.save
              shipstation_order.destroy
              shipstation_order = Order.new(store_id: @store.id)
            end
            shipstation_order
          end

          def update_order_activity_log(shipstation_order, order)
            order_import_type = @import_single_order ? 'On Demand Order Import' : (@import_webhook_order ? 'Webhook Order Import' : 'Order Import')
            shipstation_order.addactivity(order_import_type, @credential.store.name + " Import #{@ondemand_user_name}")
            shipstation_order.order_items.each_with_index do |item, index|
              intangible = order['items'][index]['adjustment'] ? true : false
              if intangible == true && (@credential.set_coupons_to_intangible || check_for_intangible_coupon)
                shipstation_order.addactivity("QTY #{item.qty} of item with SKU: #{item.product.primary_sku} Added and set to Intangible.", "#{@credential.store.name} Import")
              else
                update_activity_for_single_item(shipstation_order, item)
              end
            end
            shipstation_order.set_order_status
            update_import_result
          end

          def update_order_activity_log_for_gp_coupon(shipstation_order, order)
            order_import_type = @import_single_order ? 'On Demand Order Import' : (@import_webhook_order ? 'Webhook Order Import' : 'Order Import')
            shipstation_order.addactivity(order_import_type, @credential.store.name + " Import #{@ondemand_user_name}")
            shipstation_order.order_items.each_with_index do |item, index|
              intangible = order['items'][index]['adjustment'] ? true : false
              if intangible == true
                shipstation_order.addactivity("Intangible item with SKU #{order['items'][index]['sku']}  and Name #{order['items'][index]['name']} was replaced with GP Coupon.", "#{@credential.store.name} Import")
              end
              update_activity_for_single_item(shipstation_order, item) unless intangible
              # if order["items"][index]["name"] == item.product.name && order["items"][index]["sku"] == item.product.primary_sku
              #   update_activity_for_single_item(shipstation_order, item)
              # else
              #   intangible_strings = ScanPackSetting.all.first.intangible_string.downcase.strip.split(',')
              #   intangible_strings.each do |string|
              #     if order["items"][index]["name"].downcase.include?(string) || order["items"][index]["sku"].downcase.include?(string)
              #       shipstation_order.addactivity("Intangible item with SKU #{order["items"][index]["sku"]}  and Name #{order["items"][index]["name"]} was replaced with GP Coupon.","#{@credential.store.name} Import")
              #       break
              #     end
              #   end
              # end
            end
            shipstation_order.set_order_status
            update_import_result
          end

          def update_import_result
            if @order_to_update
              @result[:previous_imported] = @result[:previous_imported] + 1
              @import_item.update(updated_orders_import: @import_item.updated_orders_import + 1)
            else
              @result[:success_imported] = @result[:success_imported] + 1
              @import_item.update(success_imported: @result[:success_imported])
            end
          end

          def update_activity_for_single_item(shipstation_order, item)
            if item.qty.blank? || item.qty < 1
              shipstation_order.addactivity("Item with SKU: #{item.product.primary_sku} had QTY of 0 and was removed:", "#{@credential.store.name} Import")
              item.destroy
            elsif item.product.try(:primary_sku).present?
              shipstation_order.addactivity("QTY #{item.qty} of item with SKU: #{item.product.primary_sku} Added", "#{@credential.store.name} Import")
            end
          end

          def remove_gp_tags_from_ss(order)
            return unless gp_ready_tag_id != -1 && (order['tagIds'] || []).include?(gp_ready_tag_id)

            @client.remove_tag_from_order(order['orderId'], gp_ready_tag_id)
            @client.add_tag_to_order(order['orderId'], gp_imported_tag_id) if gp_imported_tag_id != -1
          end

          def product_importer_client
            @product_importer_client ||= Groovepacker::Stores::Context.new(
              Groovepacker::Stores::Handlers::ShipstationRestHandler.new(@credential.store)
            )
          end

          def destroy_nil_import_items
            ImportItem.where(store_id: @store.id, order_import_summary_id: nil).destroy_all
          rescue StandardError
            nil

            # ImportItem.where("status IS NULL").destroy_all
          end

          def create_import_summary(log)
            summary = CsvImportSummary.find_or_create_by(log_record: log.to_json)
            summary.file_name = ''
            summary.import_type = 'On demand import'
            summary.save
          end

          def find_order_in_gp(order_no)
            order_in_gp = Order.find_by_increment_id(order_no)
            order_in_gp = Order.find_by_tracking_num(order_no) if order_in_gp.nil?
            order_in_gp
          end

          def init_qf_after_on_demand(from_import_date, user_id, order_in_gp_id)
            @notify_user_id = user_id
            @notify_regular_import = true
            quick_fix_import(from_import_date, order_in_gp_id, user_id)
          end

          def should_fetch_shipments?
            @credential.import_tracking_info && ((@credential.get_active_statuses.include? 'shipped') || @credential.tag_import_option || @import_item.import_type == 'tagged')
          end

          def delete_order_and_log_event(order)
            order.destroy
            EventLog.create(data: { increment_id: order.increment_id, store_order_id: order.store_order_id }, message: 'Deleted Cancelled SS Order')
          end

          def skip_the_order?(shipments_response, order)
            # return false if @import_single_order

            @credential.import_shipped_having_tracking && order['orderStatus'] == 'shipped' && order_tracking_number(order, shipments_response).nil?
          end

          def order_tracking_number(order, shipments_response)
            if order['orderStatus'] == 'shipped'
              tracking_info = begin
                                (shipments_response || []).find { |shipment| shipment['orderId'] == order['orderId'] && shipment['voided'] == false } || {}
                              rescue StandardError
                                {}
                              end
            end
            if tracking_info.blank? && order['orderStatus'] == 'shipped' && should_fetch_shipments?
              response = @client.get_shipments_by_orderno(order['orderNumber'])
              tracking_info = {}
              if response.present?
                response.each do |shipment|
                  tracking_info = shipment if shipment['voided'] == false
                end
              end
            end
            tracking_info['trackingNumber']
          end
        end
      end
    end
  end
end
