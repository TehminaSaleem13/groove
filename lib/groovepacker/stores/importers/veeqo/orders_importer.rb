# frozen_string_literal: true

module Groovepacker
  module Stores
    module Importers
      module Veeqo
        class OrdersImporter < Importer
          include ProductsHelper
  
          def import
            init_common_objects
            @import_item.update_attributes(updated_orders_import: 0)
            if statuses.empty?
              set_status_and_msg_for_skipping_import
            else
              initialize_orders_import
            end
            update_orders_status
            destroy_nil_import_items
            @result
          end

          def initialize_orders_import
            Tenant.save_se_import_data("========Veeqo Regular Import Started UTC: #{Time.current.utc} TZ: #{Time.current}")
            begin
              OrderImportSummary.top_summary.emit_data_to_user(true)
            rescue StandardError
              nil
            end
            return @result unless @import_item.present?
  
            @import_item.update_column(:importer_id, @worker_id)
            response = get_orders_response
            @result[:total_imported] = response['orders'].nil? ? 0 : response['orders'].length
            initialize_import_item
            return @result if response['orders'].nil? || response['orders'].blank? || response['orders'].first.nil?
  
            response['orders'] = begin
                                    response['orders'].sort_by { |h| Time.zone.parse(h['updated_at']) }
                                  rescue StandardError
                                    response['orders']
                                  end
  
            ImportItem.where(store_id: @store.id).where.not(id: @import_item).update_all(status: 'cancelled')
  
            response['orders'].each do |order|
              break if import_should_be_cancelled
  
              import_single_order(order) if order.present?
            end
            send_sku_report_not_found if @result_data.count > 0
            Tenant.save_se_import_data("========Veeqo Regular Import Finished UTC: #{Time.current.utc} TZ: #{Time.current}", '==Import Item', @import_item.as_json)
            if @import_item.status != 'cancelled'
              begin
                @credential.update_attributes(last_imported_at: Time.zone.parse(response['orders'].last['updated_at']))
              rescue StandardError
                nil
              end
            end
          end
  
          def ondemand_import_single_order(order_number)
            @on_demand_import = true
            init_common_objects
            response = @client.get_single_order(order_number, @import_item)
            response['orders'].each do |order|
              import_single_order(order) if order.present?
            end
            send_sku_report_not_found if @result_data.count > 0
            begin
              @import_item.destroy
              destroy_nil_import_items
            rescue StandardError
              nil
            end
          end
  
          private

          def statuses
            @statuses ||= @credential.get_active_statuses
          end

          def check_shopify_as_a_product_source
            @credential.use_shopify_as_product_source_switch && @credential.product_source_shopify_store_id.present?
          end

          def get_orders_response
            response = { 'orders' => nil }

            statuses.each do |status|
              status_response = @client.orders(@import_item, status)
              response = get_orders_from_union(response, status_response)
            end
            response
          end

          def get_orders_from_union(response, status_response)
            response['orders'] = response['orders'].blank? ? status_response['orders'] : (response['orders'] | status_response['orders'])
            response
          end
    
          def import_single_order(order)
            @import_item.update_attributes(current_increment_id: order['number'], current_order_items: -1, current_order_imported_item: -1)
            update_import_count('success_updated') && return if skip_the_order?(order)
  
            order_in_gp_present = false
            order_in_gp = search_veeqo_order_in_db(set_order_number(order), order)
            return if handle_cancelled_order(order_in_gp)
            veeqo_shopify_order_import(order_in_gp_present, order_in_gp, order)
          end

          def destroy_nil_import_items
            ImportItem.where(store_id: @store.id, order_import_summary_id: nil).destroy_all
          rescue StandardError
            nil
          end

          def set_status_and_msg_for_skipping_import
            Order.emit_notification_all_status_disabled(@import_item.order_import_summary.user_id) if statuses.blank?

            @result[:status] = false
            @result[:messages].push(
              'All import statuses is disabled. Import skipped.'
            )
            @import_item.message = 'All import statuses is disabled. Import skipped.'
            @import_item.save
          end
  
          def import_order(veeqo_order, order)
            # veeqo_order.tags = order['tags']
            veeqo_order.increment_id = set_order_number(order)
            veeqo_order.store_order_id = order['id'].to_s
            veeqo_order.order_placed_time = Time.zone.parse(order['created_at'])
            # add order custmor info using separate method
            veeqo_order = add_customer_info(veeqo_order, order)
            # add order shipping address using separate method
            veeqo_order = add_order_shipping_address(veeqo_order, order)
            # add notes
            veeqo_order = import_notes(veeqo_order, order)
            # update shipping_amount and order weight
            # veeqo_order = update_shipping_amount_and_weight(veeqo_order, order)
            veeqo_order.order_total = order['total_price']&.to_f
            veeqo_order.last_modified = Time.zone.parse(order['updated_at'])
            veeqo_order.job_timestamp = Time.current.strftime('%Y-%m-%d %H:%M:%S.%L')
            veeqo_order
          end

          def set_order_number(order)
            @credential&.use_veeqo_order_id ? order['id'].to_s : order['number']
          end

          def import_notes(veeqo_order, order)
            veeqo_order.notes_internal = order['employee_notes'].map { |note| note['text'] }.join(', ') if @credential.shall_import_internal_notes && order['employee_notes'].present?
            veeqo_order.customer_comments = order.dig('customer_note', 'text') if @credential.shall_import_customer_notes && order['customer_note'].present?
            veeqo_order
          end

          def import_shipped_having_tracking
            @import_shipped_having_tracking ||= @credential.import_shipped_having_tracking
          end
  
          def import_veeqo_order_item(veeqo_order, order)
            return if order['line_items'].nil?

            @import_item.current_order_items = order['line_items'].length
            @import_item.current_order_imported_item = 0
            @import_item.save!
            order['line_items']&.each do |item|
              order_item = import_order_item(item)
              @import_item.update!(current_order_imported_item: @import_item.current_order_imported_item + 1)
              product = Product.joins(:product_skus).find_by(product_skus: { sku: item['sellable']['sku_code'] }) || import_order_items(item, set_order_number(order))
              if product.present?
                order_item.product = product
                veeqo_order.order_items << order_item
              else
                on_demand_logger = Logger.new("#{Rails.root}/log/#{@store.store_type.downcase}_missing_product_import_order_item_#{Apartment::Tenant.current}.log")
                log = { order_number: veeqo_order.increment_id, Time: Time.zone.now, shop_order_item: item, product: product }
                on_demand_logger.info(log)
              end
            end
            
            return unless veeqo_order.order_items.present?
            veeqo_order.save!
            veeqo_order
          end

          def import_order_items(item, order_number)
            #Check Switch Use Shopify as Product Source
            if check_shopify_as_a_product_source
              fetch_product_from_shopify(item['sellable']['sku_code'], item, order_number)
            else
              veeqo_context.import_veeqo_single_product(item)
            end
          end

          def fetch_product_from_shopify(sku, item, order_number)
            query = <<~GRAPHQL
              {
                products(first: 1, query: "sku:#{sku}") {
                  nodes {
                    id
                    title
                  }
                }
              }
            GRAPHQL

            product_res = @shopify_client.execute_grahpql_query(query: query)
            product = product_res.body.dig("data", "products", "nodes")&.first

            if product.present?
              id = product["id"].split("/").last
              item["product_id"] = id
              shopify_context.import_single_product_from_shopify_to_veeqo(item)
            else
              handle_not_found_sku(sku, order_number)
            end
          end

          def handle_not_found_sku(product_sku, order_number)
            pre_order = @result_data.find { |d| d[:order_number] == order_number }
            if pre_order.present?
               pre_order[:skus] << product_sku
            else
              @result_data << { order_number: order_number, skus: [product_sku] }
            end
            false
          end

          def send_sku_report_not_found
            VeeqoMailer.send_sku_report_not_found(Apartment::Tenant.current, @result_data, @shopify_credential.store).deliver
          end
  
          def import_order_item(line_item)
            row_total = line_item['sellable']['price'].to_f * line_item['quantity'].to_f
            OrderItem.new(qty: line_item['quantity'], price: line_item['sellable']['price'], row_total: row_total)
          end
  
          def add_customer_info(veeqo_order, order)
            return veeqo_order if order['customer'].nil?
  
            veeqo_order.email = order['customer']['email']
            veeqo_order.firstname = order['shipping_addresses'].try(:[], 'first_name')
            veeqo_order.lastname = order['shipping_addresses'].try(:[], 'last_name')
            veeqo_order
          end
  
          def add_order_shipping_address(veeqo_order, order)
            shipping_address = order['customer']['shipping_addresses']&.first
            return veeqo_order if shipping_address.blank?
  
            veeqo_order.address_1 = shipping_address['address1']
            veeqo_order.address_2 = shipping_address['address2']
            veeqo_order.city = shipping_address['city']
            veeqo_order.state = shipping_address['state']
            veeqo_order.postcode = shipping_address['zip']
            veeqo_order.country = shipping_address['country']
            veeqo_order
          end
  
          # def update_shipping_amount_and_weight(veeqo_order, order)
          #   unless order['shipping_lines'].empty?
          #     shipping = order['shipping_lines'].first
          #     veeqo_order.shipping_amount = shipping['price'].to_f unless shipping.nil?
          #   end
  
          #   veeqo_order.weight_oz = (order['allocations'].first&.dig('total_weight').to_i * 0.035274) unless order['allocations'].first&.dig('total_weight').nil?
          #   veeqo_order
          # end
  
          def veeqo_context
            handler = Groovepacker::Stores::Handlers::VeeqoHandler.new(@store)

            Groovepacker::Stores::Context.new(handler)
          end

          def shopify_context
            handler = Groovepacker::Stores::Handlers::ShopifyHandler.new(@shopify_credential.store)

            Groovepacker::Stores::Context.new(handler)
          end
  
          def update_import_count(import_type = 'success_imported')
            if import_type == 'success_imported'
              @import_item.update_attributes(success_imported: @import_item.success_imported + 1)
              @result[:success_imported] += 1
            else
              @result[:previous_imported] += 1
              @import_item.update_attributes(updated_orders_import: @import_item.updated_orders_import + 1)
            end
          end
      
          def import_order_and_items(order, order_in_gp)
            # create order
            veeqo_order = order_in_gp
            Order.transaction do
              veeqo_order = import_order(veeqo_order, order)
              # import items in an order
              veeqo_order = import_veeqo_order_item(veeqo_order, order)
              return unless veeqo_order.present?
              # add order activities
              add_order_activities(veeqo_order, order)
              # update store
              veeqo_order.set_order_status
            end
          end

          def add_order_activities(veeqo_order, order)
            activity_name = @on_demand_import ? 'On Demand Order Import' : 'Order Import'
            veeqo_order.addactivity(activity_name, @credential.store.name + ' Import')
            veeqo_order.order_items.each_with_index do |item, index|
              veeqo_order.addactivity("QTY #{item.qty} of item with SKU: #{item.sku} Added", "#{@store.name} Import")
            end
          end
    
          def skip_the_order?(order)
            return false if @on_demand_import
  
            import_shipped_having_tracking && order['status'] == 'shipped' #&& !get_tracking_number(order).present?
          end
        end
      end
    end
  end
end
