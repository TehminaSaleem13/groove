# frozen_string_literal: true

module Groovepacker
  module Stores
    module Importers
      module ShipstationRest
        include ProductsHelper
        class OrdersImporter < Groovepacker::Stores::Importers::Importer
          attr_accessor :importing_time, :quick_importing_time, :import_from, :import_date_type

          include ProductsHelper

          def import
            # this method is initializing following objects: @credential, @client, @import_item, @result
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
            response = get_orders_response
            response['orders'] = begin
              response['orders'].sort_by { |h| h['orderDate'].split('-') }
            rescue StandardError
              response['orders']
            end
            # response["orders"] = response["orders"].sort {|vn1, vn2| vn2["orderDate"] <=> vn1["orderDate"]} rescue response["orders"]
            return @result if response['orders'].blank?

            shipments_response = @client.get_shipments(import_from - 1.day)
            @result[:total_imported] = response['orders'].length
            initialize_import_item
            import_orders_from_response(response, shipments_response)
            if @result[:status] && @import_item != 'tagged'
              @credential.last_imported_at = importing_time || @credential.last_imported_at
              @credential.quick_import_last_modified = quick_importing_time || @credential.last_imported_at
              @credential.save
            end
            unless @credential.allow_duplicate_order
              a = Order.group(:increment_id).having('count(*) >1').count.keys
              unless a.empty?
                Order.where('increment_id in (?)', a).each do |o|
                  orders = Order.where(increment_id: o.increment_id)
                  orders.last.destroy if orders.count > 1
                end
              end
            end
            destroy_nil_import_items
          end

          def import_single_order(order_no)
            init_common_objects
            initialize_import_item
            @scan_settings = ScanPackSetting.last
            response, shipments_response = @client.get_order_on_demand(order_no, @import_item)
            if response['orders'].blank? && (@scan_settings.scan_by_shipping_label || @scan_settings.scan_by_packing_slip_or_shipping_label)
              response, shipments_response = @client.get_order_by_tracking_number(order_no)
            end
            import_orders_from_response(response, shipments_response)
            Order.emit_data_for_on_demand_import(response, order_no)
            @import_item.destroy
            destroy_nil_import_items
          end

          def import_orders_from_response(response, shipments_response)
            # check_or_assign_import_item
            if response['orders'].present?
              response['orders'] = response['orders'].sort_by do |order|
                Time.zone.parse(order['modifyDate'])
              end
            end
            @is_download_image = @store.shipstation_rest_credential.download_ss_image
            response['orders'].each do |order|
              import_item_fix
              break if @import_item.blank? || @import_item.try(:status) == 'cancelled' || @import_item&.status.nil?

              begin
                @import_item.update(current_increment_id: order['orderNumber'], current_order_items: -1,
                                    current_order_imported_item: -1)
                shipstation_order = find_or_init_new_order(order)
                import_order_form_response(shipstation_order, order, shipments_response)
              rescue Exception => e
              end
              break if Rails.env.test?

              sleep 0.3 unless Rails.env.test?
            end
            cred = @store.shipstation_rest_credential
            cred.download_ss_image = false
            cred.save
          end

          def import_order_form_response(shipstation_order, order, shipments_response)
            if shipstation_order.present? && !shipstation_order.persisted?
              import_order(shipstation_order, order)
              tracking_info = begin
                (shipments_response || []).find do |shipment|
                  shipment['orderId'] == order['orderId'] && shipment['voided'] == false
                end || {}
              rescue StandardError
                {}
              end
              if tracking_info.blank?
                response = @client.get_shipments_by_orderno(order['orderNumber'])
                tracking_info = {}
                if response.present?
                  response.each do |shipment|
                    tracking_info = shipment if shipment['voided'] == false
                  end
                end
              end
              shipstation_order = Order.find_by_id(shipstation_order.id) if shipstation_order.frozen?
              # if shipstation_order.frozen?
              #   new_shipstation_order = shipstation_order.dup
              #   new_shipstation_order.order_items = shipstation_order.order_items
              #   new_shipstation_order.order_shipping = shipstation_order.order_shipping
              #   new_shipstation_order.order_exception = shipstation_order.order_exception
              #   new_shipstation_order.order_activities = shipstation_order.order_serials
              #   shipstation_order.destroy
              #   shipstation_order = new_shipstation_order
              #   shipstation_order.save
              # end
              shipstation_order.tracking_num = tracking_info['trackingNumber']
              import_order_items(shipstation_order, order)
              return unless shipstation_order.save

              if check_for_replace_product
                update_order_activity_log_for_gp_coupon(shipstation_order,
                                                        order)
              else
                update_order_activity_log(shipstation_order)
              end
              remove_gp_tags_from_ss(order)
            else
              @import_item.update(updated_orders_import: @import_item.updated_orders_import + 1)
              @result[:previous_imported] = @result[:previous_imported] + 1
            end
          end

          def import_order(shipstation_order, order)
            # tenant = Apartment::Tenant.current
            # tenant = Tenant.where(name: "#{tenant}").first
            # order["customerEmail"] = nil if tenant.gdpr_shipstation

            # shipstation_order.attributes = {  increment_id: order["orderNumber"], store_order_id: order["orderId"],
            #                                   order_placed_time: order["orderDate"], email: order["customerEmail"],
            #                                   shipping_amount: order["shippingAmount"], order_total: order["amountPaid"]
            #                                 }
            # shipstation_order.last_modified  = Time.zone.parse(order['modifyDate']) + Time.zone.utc_offset
            # shipstation_order = init_shipping_address(shipstation_order, order) unless tenant.gdpr_shipstation
            # shipstation_order = import_notes(shipstation_order, order)
            # shipstation_order.weight_oz = order["weight"]["value"] rescue nil
            # shipstation_order.save
          end

          def import_order_items(shipstation_order, order)
            return if order['items'].nil?

            @import_item.update(current_order_items: order['items'].length, current_order_imported_item: 0)
            order['items'].each do |item|
              product = product_importer_client.find_or_create_product(item)
              if @is_download_image && item['imageUrl'].present? && product.product_images.blank?
                product.product_images.create(image: item['imageUrl'])
              end
              import_order_item(item, shipstation_order, product)
              @import_item.current_order_imported_item = @import_item.current_order_imported_item + 1
            end
            shipstation_order.save
            @import_item.save
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
                1.day
              end)
            when 'regular', 'quick'
              set_regular_quick_import_date
            when 'tagged'
              @import_item.update_attribute(:import_type, 'tagged')
              self.import_from = DateTime.now.in_time_zone - 1.week
            else
              set_import_date_from_store_cred
            end
            set_import_date_type
          end

          def set_regular_quick_import_date
            @import_item.update_attribute(:import_type, 'quick')
            quick_import_date = @credential.quick_import_last_modified
            self.import_from = (quick_import_date.presence || DateTime.now.in_time_zone - 5.days)
          end

          def set_import_date_from_store_cred
            @import_item.update_attribute(:import_type, 'regular')
            last_imported_at = @credential.last_imported_at
            self.import_from = last_imported_at.blank? ? DateTime.now.in_time_zone - 1.week : last_imported_at - @credential.regular_import_range.days
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

          # def init_shipping_address(shipstation_order, order)
          #   return shipstation_order if order["shipTo"].blank?
          #   address = order["shipTo"]
          #   split_name = address["name"].split(' ') rescue ' '
          #   shipstation_order.attributes = {
          #           lastname: split_name.pop, firstname: split_name.join(' '),
          #           address_1: address["street1"], address_2: address["street2"],
          #           city: address["city"], state: address["state"],
          #           postcode: address["postalCode"], country: address["country"] }
          #   return shipstation_order
          # end

          def import_notes(shipstation_order, order)
            shipstation_order.notes_internal = order['internalNotes'] if @credential.shall_import_internal_notes
            shipstation_order.customer_comments = order['customerNotes'] if @credential.shall_import_customer_notes
            shipstation_order
          end

          def get_orders_response
            response = { 'orders' => nil }
            if statuses.blank? && !@credential.tag_import_option && @import_item.import_type != 'tagged'
              Order.emit_notification_all_status_disabled(@import_item.order_import_summary.user_id)
            end
            response = fetch_orders_if_import_type_is_not_tagged(response)
            fetch_tagged_orders(response)
          end

          def fetch_orders_if_import_type_is_not_tagged(response)
            return response unless @import_item.import_type != 'tagged'

            statuses.each do |status|
              status_response = @client.get_orders(status, import_from, import_date_type)
              response = get_orders_from_union(response, status_response)
            end
            self.importing_time = DateTime.now.in_time_zone
            self.quick_importing_time = DateTime.now.in_time_zone
            response
          end

          def fetch_tagged_orders(response)
            return response unless gp_ready_tag_id != -1

            tagged_response = @client.get_orders_by_tag(gp_ready_tag_id)
            # perform union of orders
            if Apartment::Tenant.current == 'rabbitair' && tagged_response['orders'].present?
              value_1 = []
              tagged_response['orders'].each do |order|
                value_1 << order['orderNumber']
              end
              ImportMailer.check_old_orders(Apartment::Tenant.current, value_1)
            end
            get_orders_from_union(response, tagged_response)
          end

          def get_orders_from_union(response, tagged_or_status_response)
            response['orders'] =
              response['orders'].blank? ? tagged_or_status_response['orders'] : (response['orders'] | tagged_or_status_response['orders'])
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

          def find_or_init_new_order(order)
            shipstation_order = search_order_in_db(order['orderNumber'], order['orderId'])
            @order_to_update = shipstation_order.present?
            if shipstation_order && (shipstation_order.status == 'scanned' || shipstation_order.status == 'cancelled' || shipstation_order.order_items.map(&:scanned_status).include?('partially_scanned') || shipstation_order.order_items.map(&:scanned_status).include?('scanned'))
              return
            end

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

          def update_order_activity_log(shipstation_order)
            shipstation_order.addactivity('Order Import', @credential.store.name + ' Import')
            shipstation_order.order_items.each do |item|
              update_activity_for_single_item(shipstation_order, item)
            end
            shipstation_order.set_order_status
            update_import_result
          end

          def update_order_activity_log_for_gp_coupon(shipstation_order, order)
            shipstation_order.addactivity('Order Import', @credential.store.name + ' Import')
            shipstation_order.order_items.each_with_index do |item, index|
              if order['items'][index]['name'] == item.product.name && order['items'][index]['sku'] == item.product.primary_sku
                update_activity_for_single_item(shipstation_order, item)
              else
                shipstation_order.addactivity(
                  "Intangible item with SKU #{order['items'][index]['sku']}  and Name #{order['items'][index]['name']} was replaced with GP Coupon.", "#{@credential.store.name} Import"
                )
              end
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
              shipstation_order.addactivity("Item with SKU: #{item.product.primary_sku} had QTY of 0 and was removed:",
                                            "#{@credential.store.name} Import")
              item.destroy
            elsif item.product.try(:primary_sku).present?
              shipstation_order.addactivity("QTY #{item.qty} of item with SKU: #{item.product.primary_sku} Added",
                                            "#{@credential.store.name} Import")
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
        end
      end
    end
  end
end
