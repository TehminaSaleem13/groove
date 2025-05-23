# frozen_string_literal: true

module Groovepacker
  module Stores
    module Importers
      class Importer
        def initialize(handler)
          self.handler = handler
        end

        def import
          {}
        end

        def import_single(_hash)
          {}
        end

        def get_handler
          handler
        end

        def build_result
          {
            messages: [],
            previous_imported: 0,
            success_imported: 0,
            total_imported: 0,
            debug_messages: [],
            status: true
          }
        end

        # checks if product contains temp skus
        def contains_temp_skus(products)
          result = false
          products.each do |prod_item|
            unless prod_item.product_skus.where("sku LIKE 'TSKU-%'").empty?
              result = true
              break
            end
          end
          result
        end

        def get_product_with_temp_skus(products)
          result = nil
          products.each do |prod_item|
            unless prod_item.product_skus.where("sku LIKE 'TSKU-%'").empty?
              result = prod_item
              break
            end
          end
          result
        end

        def initialize_import_item
          total_imported = @result[:total_imported] || 1
          @import_item.update(current_increment_id: '',
                              success_imported: 0,
                              previous_imported: 0,
                              updated_orders_import: 0,
                              current_order_items: -1,
                              current_order_imported_item: -1,
                              to_import: total_imported)
          sleep 0.5 unless Rails.env.test?
          import_item_fix
          import_summary = OrderImportSummary.top_summary
          import_summary&.emit_data_to_user(true)
        end

        def import_item_fix
          new_import_item = @import_item
          @import_item = begin
            ImportItem.find(@import_item.id)
          rescue StandardError
            new_import_item
          end
        end

        def fix_import_item(import_item)
          new_import_item = import_item
          begin
            ImportItem.find(import_item.id)
          rescue StandardError
            new_import_item
          end
        end

        def update_success_import_count
          if @order_to_update
            @import_item.updated_orders_import += 1
            @import_item.save
            @result[:previous_imported] += 1
          else
            @import_item.success_imported += 1
            @import_item.save
            @result[:success_imported] += 1
          end
        end

        def destroy_nil_import_items
          ImportItem.where(store_id: @store.id, order_import_summary_id: nil).destroy_all
        rescue StandardError
          nil
        end

        def init_common_objects
          handler = get_handler
          @credential = handler[:credential]
          @store = @credential.store

          if @store.store_type == 'Amazon'
            @mws = handler[:store_handle][:main_handle]
            @alt_mws = handler[:store_handle][:alternate_handle]
          else
            @client = handler[:store_handle]
          end

          if @store.store_type == 'Veeqo' || @store.store_type == 'Shipstation API 2'
            @result_data = []
            @deleted_merged_orders = []
            @deleted_split_orders = []
            @shopify_credential = ShopifyCredential.find_by(store_id: @credential.product_source_shopify_store_id)
            @shopify_client = Groovepacker::ShopifyRuby::Client.new(@shopify_credential)
          end
          @import_item = handler[:import_item]
          @result = build_result
          @worker_id = 'worker_' + SecureRandom.hex
        end

        def check_shopify_as_a_product_source
          @credential.use_shopify_as_product_source_switch && @credential.product_source_shopify_store_id.present?
        end

        def fetch_and_import_shopify_product(sku, item, order_number)
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
          shopify_product = product_res.body.dig("data", "products", "nodes")&.first

          product = if shopify_product.present?
                      id = shopify_product["id"].split("/").last
                      item["product_id"] = id
                      shopify_context.import_single_shopify_product_as_source(item, sku)
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

        def shopify_context
          handler = Groovepacker::Stores::Handlers::ShopifyHandler.new(@shopify_credential.store)

          Groovepacker::Stores::Context.new(handler)
        end

        def send_sku_not_found_report_during_order_import
          ShopifyMailer.send_sku_not_found_report_during_order_import(Apartment::Tenant.current, @result_data, @shopify_credential.store, @credential.store).deliver if check_shopify_as_a_product_source
        end

        def handle_cancelled_order(gp_order)
          return false unless gp_order.present? && gp_order.status == 'cancelled'

          gp_order.destroy if @credential.remove_cancelled_orders
          true
        end

        def ondemand_user(user_id)
          return unless user_id
          user_name = User.find_by_id(user_id).name
          "(#{user_name})" if user_name
        end

        def check_or_assign_import_item
          return if ImportItem.find_by_id(@import_item.id).present?

          import_item_id = @import_item.id
          @import_item = @import_item.dup
          @import_item.id = import_item_id
          @import_item.save
        end

        def set_status_and_msg_for_skipping_import
          @result[:status] = false
          @result[:messages].push(
            'All import statuses is disabled. Import skipped.'
          )
          @import_item.message = 'All import statuses is disabled. Import skipped.'
          @import_item.save
        end

        def update_import_summary_to_in_progress
          OrderImportSummary.top_summary&.update(status: 'in_progress')
        end

        def update_import_summary_to_fetch_api_response
          OrderImportSummary.top_summary&.update(status: 'fetch_api_response')
        end

        def update_orders_status
          result = { 'status' => true, 'messages' => [], 'error_messages' => [], 'success_messages' => [],
                     'notice_messages' => [] }
          Groovepacker::Orders::BulkActions.new.delay(priority: 95).update_bulk_orders_status(result, {},
                                                                                              Apartment::Tenant.current)
        end

        def log_import_error(e)
          on_demand_logger = Logger.new("#{Rails.root.join('log/import_error_logs.log')}")
          log = { time: Time.zone.now, tenant: Apartment::Tenant.current, e:, backtrace: e.backtrace.join(',') }
          on_demand_logger.info(log)
        rescue StandardError
        end

        def import_should_be_cancelled
          @import_item.reload
          @import_item.blank? || !@import_item.persisted? || @import_item.status == 'cancelled' || @import_item.status.nil? || (@import_item.importer_id && @import_item.importer_id != @worker_id)
        rescue StandardError
          true
        end

        def veeqo_shopify_order_import(order_in_gp_present, order_in_gp, order)
          if order_in_gp.present?
            order_in_gp_present = true
            is_scanned = order_in_gp && (order_in_gp.status == 'scanned' || order_in_gp.status == 'cancelled' || order_in_gp.order_items.map(&:scanned_status).include?('partially_scanned') || order_in_gp.order_items.map(&:scanned_status).include?('scanned'))
            # mark previously imported
            if is_scanned || (order_in_gp.last_modified == Time.zone.parse(order['updated_at']))
              update_import_count('success_updated') && return
            end

            order_in_gp.order_items.destroy_all
          else
            order_in_gp = Order.new(increment_id: order['number'], store: @store, store_order_id: order['id'].to_s,
                                    importer_id: @worker_id, import_item_id: @import_item.id)
          end
          import_order_and_items(order, order_in_gp)
          order_in_gp.add_tag_from_shopify(order['tags']) if order['tags'].present? && @store.store_type == 'Shopify'

          # increase successful import with 1 and save
          order_in_gp_present ? update_import_count('success_updated') : update_import_count('success_imported')
        rescue StandardError => e
          begin
            Rollbar.error(e, e.message, Apartment::Tenant.current)
            log_import_error(e)
          rescue StandardError
            nil
          end
          update_import_count('success_imported')
        end

        def update_import_count(import_type = 'success_imported')
          if import_type == 'success_imported'
            @import_item.update(success_imported: @import_item.success_imported + 1)
            @result[:success_imported] += 1
          else
            @result[:previous_imported] += 1
            @import_item.update(updated_orders_import: @import_item.updated_orders_import + 1)
          end
        end

        def add_action_log(title, username, objects_involved, objects_involved_count)
          Ahoy::Event.version_2.create({
            name: title,
            properties: {
              title: title,
              tenant: Apartment::Tenant.current,
              username: username,
              objects_involved: objects_involved,
              objects_involved_count: objects_involved_count
            },
            time: Time.current
          }) rescue nil
        end

        protected

        attr_accessor :handler
      end
    end
  end
end
