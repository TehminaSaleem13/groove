module Groovepacker
  module ShopifyRuby
    class Client < Base
      def orders(import_item = nil)
        # page_index = 1
        combined_response = {}
        combined_response["orders"] = []
        last_import = shopify_credential.last_imported_at.utc.in_time_zone('Eastern Time (US & Canada)').to_datetime.to_s rescue (DateTime.now.utc.in_time_zone('Eastern Time (US & Canada)').to_datetime - 10.days).to_s
        fulfillment_status = shopify_credential.get_status
        # while page_index
        #   query = {"page" => page_index, "updated_at_min" => last_import, "limit" => 250}.as_json
        #   response = HTTParty.get("https://#{shopify_credential.shop_name}.myshopify.com/admin/orders?status=#{shopify_credential.shopify_status}&fulfillment_status=#{fulfillment_status}",query: query,headers: {"X-Shopify-Access-Token" => shopify_credential.access_token,"Content-Type" => "application/json","Accept" => "application/json"})
        #   page_index = page_index + 1
        #   combined_response["orders"] << response["orders"]
        #   break if (response["orders"].blank? || response["orders"].count < 250)
        # end

        query = {"updated_at_min" => last_import, "limit" => 250}.as_json
        response = HTTParty.get("https://#{shopify_credential.shop_name}.myshopify.com/admin/api/2019-10/orders?status=#{shopify_credential.shopify_status}&fulfillment_status=#{fulfillment_status}",query: query,headers: {"X-Shopify-Access-Token" => shopify_credential.access_token,"Content-Type" => "application/json","Accept" => "application/json"})
        combined_response["orders"] << response["orders"]

        while response.headers['link'].present? && (response.headers['link'].include? 'next')
          import_item&.touch rescue nil
          new_link = response.headers['link'].split(',').last.split(';').first.strip.chop.reverse.chop.reverse
          response = HTTParty.get(new_link, headers: {"X-Shopify-Access-Token" => shopify_credential.access_token,"Content-Type" => "application/json","Accept" => "application/json"})
          combined_response["orders"] << response["orders"]
        end

        combined_response["orders"] = combined_response["orders"].flatten
        Tenant.save_se_import_data("========Shopify Import Started UTC: #{Time.now.utc} TZ: #{Time.now.utc + (GeneralSetting.last.time_zone.to_i || 0)}", '==Query', query, '==URL', "https://#{shopify_credential.shop_name}.myshopify.com/admin/api/2019-10/orders?status=#{shopify_credential.shopify_status}&fulfillment_status=#{fulfillment_status}", '==Combined Response', combined_response)
        combined_response
      end

      def products(product_import_type, product_import_range_days)
        page_index = 1
        combined_response = {}
        combined_response["products"] = []
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
        query_opts = { "limit" => 100 }.as_json

        add_url = product_import_type == 'new_updated' && shopify_credential.product_last_import ? "?updated_at_min=#{shopify_credential.product_last_import.strftime("%Y-%m-%d %H:%M:%S").gsub(' ', '%20')}" : ''
        add_url = product_import_type == 'refresh_catalog' && product_import_range_days.to_i > 0 ? "?updated_at_min=#{(DateTime.now - product_import_range_days.to_i).strftime("%Y-%m-%d %H:%M:%S").gsub(' ', '%20')}" : '' unless add_url.present?

        response = HTTParty.get("https://#{shopify_credential.shop_name}.myshopify.com/admin/api/2019-10/products#{add_url}",
                                  query: query_opts,
                                  headers: {
                                  "X-Shopify-Access-Token" => shopify_credential.access_token,
                                  "Content-Type" => "application/json",
                                  "Accept" => "application/json"
                                })
        combined_response["products"] << response["products"]
        combined_response["products"] = combined_response["products"].flatten

        while response.headers['link'].present? && (response.headers['link'].include? 'next')
          page_index = page_index + 1
          puts "======================Fetching Page #{page_index}======================"
          new_link = response.headers['link'].split(',').last.split(';').first.strip.chop.reverse.chop.reverse
          response = HTTParty.get(new_link, headers: {"X-Shopify-Access-Token" => shopify_credential.access_token,"Content-Type" => "application/json","Accept" => "application/json"})
          combined_response["products"] << response["products"]
          combined_response["products"] = combined_response["products"].flatten
        end
        combined_response
      end

      def formatted_product_import_date(date)
        "?updated_at_min=#{date.to_json.gsub("\"", '').gsub('Z', '-00:00')}"
      end

      def product(product_id)
        response = HTTParty.get('https://'+ shopify_credential.shop_name +
                                  '.myshopify.com/admin/products/' + product_id.to_s,
                                headers: {
                                  "X-Shopify-Access-Token" => shopify_credential.access_token,
                                  "Content-Type" => "application/json",
                                  "Accept" => "application/json"
                                })
        response
      end

      def get_variant(product_variant_id)
        response = HTTParty.get("https://#{shopify_credential.shop_name}.myshopify.com/admin/variants/#{product_variant_id}",
                                headers: {
                                  "X-Shopify-Access-Token" => shopify_credential.access_token,
                                  "Content-Type" => "application/json",
                                  "Accept" => "application/json"
                                })
        #unless sku.blank?
        #  response["variants"] = response["variants"].select {|variant| variant["sku"]==sku} rescue {}
        #  response = response["variants"].first || {}
        #end
        return response["variant"] || {}
      end

      def update_inventory(sync_option, attrs)

				response = HTTParty.put("https://#{shopify_credential.shop_name}.myshopify.com/admin/variants/#{sync_option.shopify_product_variant_id}",
                                body: attrs.to_json,
                                headers: {
                                  "X-Shopify-Access-Token" => shopify_credential.access_token,
                                  "Content-Type" => "application/json",
                                  "Accept" => "application/json"
                                })
      end

    end
  end
end
