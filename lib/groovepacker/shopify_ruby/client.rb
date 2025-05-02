# frozen_string_literal: true

module Groovepacker
  module ShopifyRuby
    class Client < Base
      SHOPIFY_API_LIMIT = 250

      def graphql_client
        ShopifyAPI::Clients::Graphql::Admin.new(
          session:, api_version: ENV['SHOPIFY_GRAPHQL_API_VERSION']
        )
      end

      def orders(import_item = nil)
        page_index = 1
        combined_response = {}
        combined_response['orders'] = []
        cred_last_imported = shopify_credential.last_imported_at
        cred_created_at = shopify_credential.order_import_range_days
        created_at = (ActiveSupport::TimeZone['Eastern Time (US & Canada)'].parse(Time.zone.now.to_s) - cred_created_at.days).to_datetime.to_s
        last_import = if cred_last_imported
                        cred_last_imported.utc.in_time_zone('Eastern Time (US & Canada)').to_datetime.to_s
                      else
                        Order.emit_notification_for_default_import_date(import_item&.order_import_summary&.user_id,
                                                                        shopify_credential.store, nil, 10)
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

        Rails.logger.info("======================Fetching Page #{page_index}======================")
        query = { 'updated_at_min' => last_import, 'limit' => 250 }.as_json
        query.merge!('created_at_min' => created_at) unless cred_created_at == 0
        response = HTTParty.get(
          "https://#{shopify_credential.shop_name}.myshopify.com/admin/api/#{ENV['SHOPIFY_API_VERSION']}/orders?status=#{shopify_credential.shopify_status}&fulfillment_status=#{fulfillment_status}", query:, headers:
        )
        orders = JSON.parse(response.body)['orders']
        orders.reject! { |order| order['cancelled_at'].present? } if shopify_credential.shopify_status == 'any'
        combined_response['orders'] << orders

        while response.headers['link'].present? && (response.headers['link'].include? 'next')
          page_index += 1
          Rails.logger.info("======================Fetching Page #{page_index}======================")
          begin
            import_item&.touch
          rescue StandardError
            nil
          end
          new_link = response.headers['link'].split(',').last.split(';').first.strip.chop.reverse.chop.reverse
          response = HTTParty.get(new_link, headers:)
          combined_response['orders'] << response['orders']
        end

        combined_response['orders'] = combined_response['orders'].flatten
        Tenant.save_se_import_data("========Shopify Import Started UTC: #{Time.current.utc} TZ: #{Time.current}",
                                   '==Query', query, '==URL', "https://#{shopify_credential.shop_name}.myshopify.com/admin/api/#{ENV['SHOPIFY_API_VERSION']}/orders?status=#{shopify_credential.shopify_status}&fulfillment_status=#{fulfillment_status}", '==Combined Response', combined_response)
        combined_response
      end

      def get_single_order(order_number)
        query = { limit: 5 }.as_json
        response = HTTParty.get(
          "https://#{shopify_credential.shop_name}.myshopify.com/admin/api/#{ENV['SHOPIFY_API_VERSION']}/orders?name=#{order_number}&status=any", query:, headers:
        )
        Tenant.save_se_import_data(
          "========Shopify On Demand Import Started UTC: #{Time.current.utc} TZ: #{Time.current}", '==Number', order_number, '==Response', response
        )
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

        add_url = if product_import_type == 'new_updated' && shopify_credential.product_last_import
                    "?updated_at_min=#{shopify_credential.product_last_import.strftime('%Y-%m-%d %H:%M:%S').gsub(
                      ' ', '%20'
                    )}"
                  else
                    ''
                  end
        unless add_url.present?
          add_url = if product_import_type == 'refresh_catalog' && product_import_range_days.to_i > 0
                      "?updated_at_min=#{(DateTime.now.in_time_zone - product_import_range_days.to_i.days).strftime('%Y-%m-%d %H:%M:%S').gsub(
                        ' ', '%20'
                      )}"
                    else
                      ''
                    end
        end

        response = HTTParty.get("https://#{shopify_credential.shop_name}.myshopify.com/admin/api/#{ENV['SHOPIFY_API_VERSION']}/products#{add_url}",
                                query: query_opts,
                                headers:)
        combined_response['products'] << response['products']
        combined_response['products'] = combined_response['products'].flatten

        while response.headers['link'].present? && (response.headers['link'].include? 'next')
          page_index += 1
          puts "======================Fetching Page #{page_index}======================"
          new_link = response.headers['link'].split(',').last.split(';').first.strip.chop.reverse.chop.reverse
          response = HTTParty.get(new_link, headers:)
          combined_response['products'] << response['products']
          combined_response['products'] = combined_response['products'].flatten
        end
        combined_response
      end

      def formatted_product_import_date(date)
        "?updated_at_min=#{date.to_json.delete('"').gsub('Z', '-00:00')}"
      end

      def product(product_id)
        result = fetch_from_shopify { ShopifyAPI::Product.find(session:, id: product_id) }
        result.success? ? result.response.as_json : {}
      end

      def get_variant(product_variant_id)
        result = fetch_from_shopify { ShopifyAPI::Variant.find(session:, id: product_variant_id) }
        result.success? ? result.response.as_json : {}
      end

      def update_inventory(attrs)
        response = nil
        loop do
          response = HTTParty.post("https://#{shopify_credential.shop_name}.myshopify.com/admin/api/#{ENV['SHOPIFY_API_VERSION']}/inventory_levels/set.json",
                                   body: attrs.to_json, headers:)
          return response if response.success? || response.code != 429

          sleep(response.headers['Retry-After'].to_f)
        end
        response
      end

      def add_gp_scanned_tag(store_order_id, tag)
        order = get_order(store_order_id)
        tags = order['tags'].split(', ').push(tag).uniq.join(', ')
        attrs = { order: { id: store_order_id, tags: } }

        sleep 0.5 unless Rails.env.test?

        update_order(store_order_id, attrs)
      end

      def mark_order_items_fulfilled(store_order_id)
        begin
          fulfillment_order = fetch_from_shopify { ShopifyAPI::FulfillmentOrder.all(session: session, order_id: store_order_id).last }
          shopify_fulfillment_order = fulfillment_order.response
        
          line_items_hash = shopify_fulfillment_order.line_items.map do |line_item|
            { id: line_item['id'], quantity: line_item['quantity'] }
          end

          return if line_items_hash.blank?

          fulfillment = ShopifyAPI::Fulfillment.new(session: session)
          fulfillment.order_id = shopify_fulfillment_order.order_id
          fulfillment.location_id = shopify_fulfillment_order.assigned_location_id
          fulfillment.line_items_by_fulfillment_order = [
            {
              fulfillment_order_id: shopify_fulfillment_order.id,
              fulfillment_order_line_items: line_items_hash
            }
          ]

          fulfillment.save!
        rescue => e
          puts e
        end
      end

      def update_order(store_order_id, attrs)
        HTTParty.put("https://#{shopify_credential.shop_name}.myshopify.com/admin/api/#{ENV['SHOPIFY_API_VERSION']}/orders/#{store_order_id}.json",
                     body: attrs.to_json, headers:)
      end

      def get_order(store_order_id)
        response = HTTParty.get("https://#{shopify_credential.shop_name}.myshopify.com/admin/api/#{ENV['SHOPIFY_API_VERSION']}/orders/#{store_order_id}.json",
                                headers:)
        response['order'] || {}
      end

      def inventory_levels(location_id)
        fetch_collection_from_shopify('ShopifyAPI::InventoryLevel', location_ids: location_id)
      end

      def locations
        fetch_collection_from_shopify('ShopifyAPI::Location')
      end

      def access_scopes
        ShopifyAPI::AccessScope.all(session:).map(&:handle)
      rescue StandardError => e
        nil
      end

      def execute_grahpql_query(params)
        graphql_client.query(**params)
      end

      def register_webhook(attrs)
        return
        # TODO: Commenting this as it is not being used.
        HTTParty.post("https://#{shopify_credential.shop_name}.myshopify.com/admin/api/#{ENV['SHOPIFY_WEBHOOK_VERSION']}/webhooks.json",
                      body: attrs.to_json, headers:)
      end

      def list_webhooks
        return []
        # TODO: Commenting this as it is not being used.
        response = HTTParty.get("https://#{shopify_credential.shop_name}.myshopify.com/admin/api/#{ENV['SHOPIFY_WEBHOOK_VERSION']}/webhooks.json",
                                headers:)
        response['webhooks'] || []
      end

      def delete_webhook(webhook_id)
        return
        # TODO: Commenting this as it is not being used.
        response = HTTParty.delete(
          "https://#{shopify_credential.shop_name}.myshopify.com/admin/api/#{ENV['SHOPIFY_WEBHOOK_VERSION']}/webhooks/#{webhook_id}.json", headers:
        )
      end

      private

      def fetch_collection_from_shopify(collection_klass, query = {})
        default_query = { session:, limit: SHOPIFY_API_LIMIT }
        page = 1
        puts "Fetching Page #{page} of #{collection_klass} for [#{Apartment::Tenant.current}] Store ID #{shopify_credential.store_id} "
        collection_response = fetch_from_shopify { collection_klass.constantize.send(:all, default_query.merge(query)) }
        return [] unless collection_response.success?

        while collection_klass.constantize.next_page_info
          page += 1
          puts "Fetching Page #{page} of #{collection_klass} for [#{Apartment::Tenant.current}] Store ID #{shopify_credential.store_id} "
          result = fetch_from_shopify do
            collection_klass.constantize.send(:all,
                                              default_query.merge(page_info: collection_klass.constantize.next_page_info))
          end
          collection_response.response += result.response
        end
        collection_response.response.as_json
      end

      def fetch_from_shopify(&_block)
        raise unless block_given?

        result = Result.new
        begin
          response = yield
          result.success!(response)
        rescue ShopifyAPI::Errors::HttpResponseError => e
          if e.response&.code == 429
            sleep e.response.headers['retry-after']&.join.to_f
            retry
          end
          Rails.logger.error("Shopify API HTTP error: #{e.message}")
          Rails.logger.error("Response code: #{e.response&.code}")
          result.failure!(e.message)
        rescue StandardError => e
          log_shopify_api_error(e)
          result.failure!(e.message)
        end
        result
      end

      def session
        @session ||= ShopifyAPI::Auth::Session.new(
          shop: "#{shopify_credential&.shop_name}.myshopify.com",
          access_token: shopify_credential&.access_token
        )
      end

      def log_shopify_api_error(error)
        Rails.logger.error("An error occurred: #{error.message}")
        log = { tenant: Apartment::Tenant.current, session:, time: Time.current.utc, error:,
                backtrace: error.backtrace.first(3) }
        shopify_error_logger.error(log)
      end

      def shopify_error_logger
        @shopify_error_logger ||= Logger.new("#{Rails.root.join('log/shopify_api_errors.log')}")
      end

      def headers
        {
          'X-Shopify-Access-Token' => shopify_credential&.access_token,
          'Content-Type' => 'application/json',
          'Accept' => 'application/json',
          'Content-Security-Policy' => 'frame-ancestors'
        }
      end
    end
  end
end
