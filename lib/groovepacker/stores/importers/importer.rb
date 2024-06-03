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
          @import_item.update_attributes(current_increment_id: '',
                                         success_imported: 0,
                                         previous_imported: 0,
                                         updated_orders_import: 0,
                                         current_order_items: -1,
                                         current_order_imported_item: -1,
                                         to_import: total_imported)
          sleep 0.5
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
          import_item = begin
                          ImportItem.find(import_item.id)
                        rescue StandardError
                          new_import_item
                        end
          import_item
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
          if @store.store_type == 'Veeqo'
            @result_data = []
            @shopify_credential = ShopifyCredential.find_by(store_id: @credential.product_source_shopify_store_id)
            @shopify_client = Groovepacker::ShopifyRuby::Client.new(@shopify_credential)
          end
          @import_item = handler[:import_item]
          @result = build_result
          @worker_id = 'worker_' + SecureRandom.hex
        end

        def handle_cancelled_order(gp_order)
          return false unless gp_order.present? && gp_order.status == 'cancelled'

          if @credential.remove_cancelled_orders
            gp_order.destroy
          end
          true
        end

        def check_or_assign_import_item
          return unless ImportItem.find_by_id(@import_item.id).blank?

          import_item_id = @import_item.id
          @import_item = @import_item.dup
          @import_item.id = import_item_id
          @import_item.save
        end

        def update_orders_status
          result = { 'status' => true, 'messages' => [], 'error_messages' => [], 'success_messages' => [], 'notice_messages' => [] }
          Groovepacker::Orders::BulkActions.new.delay(priority: 95).update_bulk_orders_status(result, {}, Apartment::Tenant.current)
        end

        def log_import_error(e)
          on_demand_logger = Logger.new("#{Rails.root}/log/import_error_logs.log")
          log = { time: Time.zone.now, tenant: Apartment::Tenant.current, e: e, backtrace: e.backtrace.join(',') }
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
            update_import_count('success_updated') && return if is_scanned || (order_in_gp.last_modified == Time.zone.parse(order['updated_at']))
            order_in_gp.order_items.destroy_all
          else
            order_in_gp = Order.new(increment_id: order['number'], store: @store, store_order_id: order['id'].to_s, importer_id: @worker_id, import_item_id: @import_item.id)
          end
          import_order_and_items(order, order_in_gp)
          order_in_gp.add_tag_from_shopify(order['tags']) if order['tags'].present? && @store.store_type == "Shopify"

          # increase successful import with 1 and save
          order_in_gp_present ? update_import_count('success_updated') : update_import_count('success_imported')
          begin
              @credential.update_attributes(last_imported_at: Time.zone.parse(order['updated_at'])) unless @on_demand_import
          rescue StandardError
            nil
            end
        rescue StandardError => e
          begin
            Rollbar.error(e, e.message, Apartment::Tenant.current)
            log_import_error(e)
          rescue StandardError
            nil
            end
          update_import_count('success_imported')
        end

        protected

        attr_accessor :handler
      end
    end
  end
end
