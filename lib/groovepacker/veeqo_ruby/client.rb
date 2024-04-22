# frozen_string_literal: true

module Groovepacker
  module VeeqoRuby
    class Client < Base

      def orders(import_item = nil, status)
        page = 1
        combined_response = { 'orders' => [] }
        cred_last_imported = veeqo_credential.last_imported_at
        cred_created_at = veeqo_credential.order_import_range_days
        time_zone = "Eastern Time (US & Canada)"
        created_at_min = (ActiveSupport::TimeZone[time_zone].parse(Time.zone.now.to_s) - cred_created_at.days).to_datetime.to_s
        updated_at_min = if cred_last_imported
                        cred_last_imported.utc.in_time_zone(time_zone).to_datetime.to_s
                      else
                        Order.emit_notification_for_default_import_date(import_item&.order_import_summary&.user_id, veeqo_credential.store, nil, 10)
                        (DateTime.now.utc.in_time_zone(time_zone).to_datetime - 10.days).to_s
                      end

        Rails.logger.info("======================Fetching Page #{page} Status #{status}======================")
        response = HTTParty.get("https://api.veeqo.com/orders?status=#{status}&created_at_min=#{created_at_min}&updated_at_min=#{updated_at_min}&page=#{page}&page_size=100", headers: headers)
        combined_response['orders'] = union(combined_response['orders'], response.parsed_response) if response.parsed_response.present?

        while response.headers['x-total-pages-count'].present? && response.headers['x-total-pages-count'].to_i > page
          page += 1
          Rails.logger.info("======================Fetching Page #{page} Status #{status}======================")
          begin
            import_item&.touch
          rescue StandardError
            nil
          end
          response = HTTParty.get("https://api.veeqo.com/orders?status=#{status}&created_at_min=#{created_at_min}&updated_at_min=#{updated_at_min}&page=#{page}&page_size=100", headers: headers)
          combined_response['orders'] = union(combined_response['orders'], response.parsed_response) if response.parsed_response.present?
        end

        combined_response['orders'] = combined_response['orders'].flatten
        Tenant.save_se_import_data("========Veeqo Import Started UTC: #{Time.current.utc} TZ: #{Time.current}", '==URL', "https://api.veeqo.com/orders?status=#{status}&created_at_min=#{created_at_min}&updated_at_min=#{updated_at_min}&page=#{page}&page_size=100", '==Combined Response', combined_response)
        combined_response
      end

      # def get_single_order(order_number)
      #   query = { limit: 5 }.as_json
      #   response = HTTParty.get("https://api.veeqo.com/orders?updated_at_min=#{last_import}&page=#{page}&page_size=100", headers: headers)
      #   Tenant.save_se_import_data("========Veeqo On Demand Import Started UTC: #{Time.current.utc} TZ: #{Time.current}", '==Number', order_number, '==Response', response)
      #   response
      # end

      private

      def union(orders, second_set)
        begin
          orders += second_set unless second_set.try(:length).to_i == 0
        rescue StandardError
          nil
        end
        orders
      end

      def headers
        {
          'x-api-key' => veeqo_credential&.api_key,
          'Content-Type' => 'application/json',
          'Accept' => 'application/json'
        }
      end
    end
  end
end
