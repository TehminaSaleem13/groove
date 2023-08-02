# frozen_string_literal: true

module Groovepacker
  module ShopifyRuby
    class Client < Base
      def orders(import_item = nil)
        # page_index = 1
        combined_response = {}
        combined_response['orders'] = []
        cred_last_imported = shopify_credential.last_imported_at
        last_import = if cred_last_imported
                        cred_last_imported.utc.in_time_zone('Eastern Time (US & Canada)').to_datetime.to_s
                      else
                        Order.emit_notification_for_default_import_date(import_item&.order_import_summary&.user_id, shopify_credential.store, nil, 10)
                        (DateTime.now.utc.in_time_zone('Eastern Time (US & Canada)').to_datetime - 10.days).to_s
                      end
        fulfillment_status = shopify_credential.get_status
        # while page_index
        #   query = {"page" => page_index, "updated_at_min" => last_import, "limit" => 250}.as_json
        #   response = HTTParty.get("https://#{shopify_credential.shop_name}.myshopify.com/admin/orders?status=#{shopify_credential.shopify_status}&fulfillment_status=#{fulfillment_status}", query: query, headers: headers)
        #   page_index = page_index + 1
        #   combined_response["orders"] << response["orders"]
        #   break if (response["orders"].blank? || response["orders"].count < 250)
        # end

        query = { 'updated_at_min' => last_import, 'limit' => 250 }.as_json
        response = HTTParty.get("https://#{shopify_credential.shop_name}.myshopify.com/admin/api/2022-10/orders?status=#{shopify_credential.shopify_status}&fulfillment_status=#{fulfillment_status}", query: query, headers: headers)
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
        Tenant.save_se_import_data("========Shopify Import Started UTC: #{Time.current.utc} TZ: #{Time.current}", '==Query', query, '==URL', "https://#{shopify_credential.shop_name}.myshopify.com/admin/api/2022-10/orders?status=#{shopify_credential.shopify_status}&fulfillment_status=#{fulfillment_status}", '==Combined Response', combined_response)
        combined_response
      end

      def get_single_order(order_number)
        query = { limit: 5 }.as_json
        response = HTTParty.get("https://#{shopify_credential.shop_name}.myshopify.com/admin/api/2022-10/orders?name=#{order_number}", query: query, headers: headers)
        Tenant.save_se_import_data("========Shopify On Demand Import Started UTC: #{Time.current.utc} TZ: #{Time.current}", '==Number', order_number, '==Response', response)
        response
      end

      def products(product_import_type, product_import_range_days)
        page_index = 1
        combined_response = {}
        combined_response['products'] = []
        # while page_index
        #   puts "======================Fetching Page #{page_index}======================"
        #   query_opts = {"page" => page_index, "limit" => 100}.as_json
        #   add_url = product_import_type == 'new_updated' && shopify_credential.product_last_import ? formatted_product_import_date(shopify_credential.product_last_import) : ''
        #   response = HTTParty.get("https://#{shopify_credential.shop_name}.myshopify.com/admin/products#{add_url}",
        #                             query: query_opts,
        #                             headers: {
        #                             "X-Shopify-Access-Token" => shopify_credential.access_token,
        #                             "Content-Type" => "application/json",
        #                             "Accept" => "application/json"
        #                           })
        #   page_index = page_index + 1
        #   combined_response["products"] << response["products"]
        #   combined_response["products"] = combined_response["products"].flatten
        #   break if (response["products"].blank? || response["products"].count < 100)
        # end
        puts "======================Fetching Page #{page_index}======================"
        query_opts = { 'limit' => 100 }.as_json

        add_url = product_import_type == 'new_updated' && shopify_credential.product_last_import ? "?updated_at_min=#{shopify_credential.product_last_import.strftime('%Y-%m-%d %H:%M:%S').gsub(' ', '%20')}" : ''
        add_url = product_import_type == 'refresh_catalog' && product_import_range_days.to_i > 0 ? "?updated_at_min=#{(DateTime.now.in_time_zone - product_import_range_days.to_i.days).strftime('%Y-%m-%d %H:%M:%S').gsub(' ', '%20')}" : '' unless add_url.present?

        response = HTTParty.get("https://#{shopify_credential.shop_name}.myshopify.com/admin/api/2022-10/products#{add_url}",
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

      def formatted_product_import_date(date)
        "?updated_at_min=#{date.to_json.delete('"').gsub('Z', '-00:00')}"
      end

      def product(product_id)
        response = HTTParty.get('https://' + shopify_credential.shop_name +
                                  '.myshopify.com/admin/products/' + product_id.to_s,
                                headers: headers)
        response
      end

      def get_variant(product_variant_id)
        response = HTTParty.get("https://#{shopify_credential.shop_name}.myshopify.com/admin/variants/#{product_variant_id}",
                                headers: headers)
        # unless sku.blank?
        #  response["variants"] = response["variants"].select {|variant| variant["sku"]==sku} rescue {}
        #  response = response["variants"].first || {}
        # end
        response['variant'] || {}
      end

      def update_inventory(attrs)
        response = HTTParty.post("https://#{shopify_credential.shop_name}.myshopify.com/admin/inventory_levels/set.json",
                                 body: attrs.to_json, headers: headers)
      end

      def add_gp_scanned_tag(store_order_id, tag)
        order = get_order(store_order_id)
        tags = order['tags'].split(', ').push(tag).uniq.join(', ')
        attrs = { order: { id: store_order_id, tags: tags } }

        sleep 0.5

        update_order(store_order_id, attrs)
      end

      def update_order(store_order_id, attrs)
        response = HTTParty.put("https://#{shopify_credential.shop_name}.myshopify.com/admin/orders/#{store_order_id}.json",
                                 body: attrs.to_json, headers: headers)
        response
      end

      def get_order(store_order_id)
        response = HTTParty.get("https://#{shopify_credential.shop_name}.myshopify.com/admin/orders/#{store_order_id}.json",
                                 headers: headers)
        response['order'] || {}
      end

      def locations
        response = HTTParty.get("https://#{shopify_credential.shop_name}.myshopify.com/admin/locations.json",
                                headers: headers)
        response['locations'] || []
      end

      def headers
        {
          'X-Shopify-Access-Token' => shopify_credential.access_token,
          'Content-Type' => 'application/json',
          'Accept' => 'application/json',
          'Content-Security-Policy' => 'frame-ancestors'
        }
      end
    end
  end
end
