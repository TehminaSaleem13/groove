# frozen_string_literal: true

module Groovepacker
  module ShoplineRuby
    class Client < Base
      SHOPLINE_API_LIMIT = 250

      def orders(import_item = nil)
        # page_index = 1
        combined_response = {}
        combined_response['orders'] = []
        cred_last_imported = shopline_credential.last_imported_at
        last_import = if cred_last_imported
                        cred_last_imported.utc.in_time_zone('Eastern Time (US & Canada)').to_datetime.to_s
                      else
                        Order.emit_notification_for_default_import_date(import_item&.order_import_summary&.user_id, shopline_credential.store, nil, 10)
                        (DateTime.now.utc.in_time_zone('Eastern Time (US & Canada)').to_datetime - 10.days).to_s
                      end
        fulfillment_status = shopline_credential.get_status
        # while page_index
        #   query = {"page" => page_index, "updated_at_min" => last_import, "limit" => 250}.as_json
        #   response = HTTParty.get("https://#{shopline_credential.shop_name}.myshopline.com/admin/orders.json?status=#{shopline_credential.shopline_status}&fulfillment_status=#{fulfillment_status}", query: query, headers: headers)
        #   page_index = page_index + 1
        #   combined_response["orders"] << response["orders"]
        #   break if (response["orders"].blank? || response["orders"].count < 250)
        # end

        query = {
          updated_at_min: last_import,
          status: shopline_credential.shopline_status,
          fulfillment_status: fulfillment_status,
          limit: 100
        }.as_json

        response = HTTParty.get(
          "https://#{shopline_credential.shop_name}.myshopline.com/admin/openapi/#{ENV['SHOPLINE_API_VERSION']}/orders.json",
          query: query,
          headers: headers
        )

        combined_response['orders'] << response['orders']

        while response.headers['link'].present? && (response.headers['link'].include? 'next')
          begin
            import_item&.touch
          rescue StandardError
            nil
          end
          new_link = response.headers['link'].split(',').last.split(';').first.strip.chop.reverse.chop.reverse
          response = HTTParty.get(new_link, headers: headers)
          combined_response['orders'] << response['orders']
        end

        combined_response['orders'] = combined_response['orders'].flatten
        Tenant.save_se_import_data("========Shopify Import Started UTC: #{Time.current.utc} TZ: #{Time.current}", '==Query', query, '==URL', "https://#{shopline_credential.shop_name}.myshopline.com/admin/openapi/#{ENV['SHOPLINE_API_VERSION']}/orders.json?status=#{shopline_credential.shopline_status}&fulfillment_status=#{fulfillment_status}", '==Combined Response', combined_response)
        combined_response
      end

      def get_single_order(order_number)
        query = { limit: 5 }.as_json
        response = HTTParty.get("https://#{shopline_credential.shop_name}.myshopline.com/admin/openapi/#{ENV['SHOPLINE_API_VERSION']}/orders.json?name=#{order_number}", query: query, headers: headers)
        Tenant.save_se_import_data("========Shopify On Demand Import Started UTC: #{Time.current.utc} TZ: #{Time.current}", '==Number', order_number, '==Response', response)
        response
      end

      def products(product_import_type, product_import_range_days)
        page_index = 1
        combined_response = {}
        combined_response['products'] = []

        puts "======================Fetching Page #{page_index}======================"
        query_opts = { 'limit' => 100 }.as_json

        add_url = product_import_type == 'new_updated' && shopline_credential.product_last_import ? "?updated_at_min=#{shopline_credential.product_last_import.strftime('%Y-%m-%d %H:%M:%S').gsub(' ', '%20')}" : ''
        add_url = product_import_type == 'refresh_catalog' && product_import_range_days.to_i > 0 ? "?updated_at_min=#{(DateTime.now.in_time_zone - product_import_range_days.to_i.days).strftime('%Y-%m-%d %H:%M:%S').gsub(' ', '%20')}" : '' unless add_url.present?

        response = HTTParty.get("https://#{shopline_credential.shop_name}.myshopline.com/admin/openapi/#{ENV['SHOPLINE_API_VERSION']}/products/products.json#{add_url}",
                                query: query_opts,
                                headers: headers)
        combined_response['products'] << response['products']
        combined_response['products'] = combined_response['products'].flatten

        while response.headers['link'].present? && (response.headers['link'].include? 'next')
          page_index += 1
          puts "======================Fetching Page #{page_index}======================"
          new_link = response.headers['link'].split(',').last.split(';').first.strip.chop.reverse.chop.reverse
          response = HTTParty.get(new_link, headers: headers)
          combined_response['products'] << response['products']
          combined_response['products'] = combined_response['products'].flatten
        end
        combined_response
      end

      def product(product_id)
        HTTParty.get(
          "https://#{shopline_credential.shop_name}.myshopline.com/admin/openapi/#{ENV['SHOPLINE_API_VERSION']}/products/#{product_id}.json",
          headers: headers
        )
      end

      def get_variant(product_variant_id)
        response = HTTParty.get(
          "https://#{shopline_credential.shop_name}.myshopline.com/admin/openapi/#{ENV['SHOPLINE_API_VERSION']}/products/variants/#{product_variant_id}.json",
          headers: headers
        )
        response['variant']
      end

      def update_inventory(attrs)
        response = nil
        loop do
          response = HTTParty.post("https://#{shopline_credential.shop_name}.myshopline.com/admin/openapi/#{ENV['SHOPLINE_API_VERSION']}/inventory_levels/set.json",
                                   body: attrs.to_json, headers: headers)
          return response if response.success? || response.code != 429

          sleep(response.headers['Retry-After'].to_f)
        end
        response
      end

      def update_order(store_order_id, attrs)
        response = HTTParty.put("https://#{shopline_credential.shop_name}.myshopline.com/admin/orders/#{store_order_id}.json",
                                 body: attrs.to_json, headers: headers)
        response
      end

      def get_order(store_order_id)
        response = HTTParty.get("https://#{shopline_credential.shop_name}.myshopline.com/admin/orders/#{store_order_id}.json",
                                 headers: headers)
        response['order'] || {}
      end

      def inventory_levels(inventory_item_id, location_id)
        query = { inventory_item_ids: inventory_item_id }.as_json
        HTTParty.get(
          "https://#{shopline_credential.shop_name}.myshopline.com/admin/openapi/#{ENV['SHOPLINE_API_VERSION']}/inventory_levels.json",
          query: query,
          headers: headers
        )
      end

      def locations
        HTTParty.get(
          "https://#{shopline_credential.shop_name}.myshopline.com/admin/openapi/#{ENV['SHOPLINE_API_VERSION']}/locations/list.json",
          headers: headers
        )
      end

      def adjust_inventory(attrs)
        HTTParty.post(
          "https://#{shopline_credential.shop_name}.myshopline.com/admin/openapi/#{ENV['SHOPLINE_API_VERSION']}/inventory_levels/adjust.json",
          body: attrs,
          headers: headers
        )
      end

      private

      def headers
        {
          'Authorization' => "Bearer #{shopline_credential&.access_token}",
          'Accept' => 'application/json'
        }
      end
    end
  end
end
