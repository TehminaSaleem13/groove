# frozen_string_literal: true

module Groovepacker
  module Orders
    class OrdersFilter < Groovepacker::Orders::Base
      OPERATORS_MAP = {
        'before' => '<', 
        'after' => '>', 
        'beforeOrOn' => '<=', 
        'afterOrOn' => '>=', 
        'gte' => '>=', 
        'gt' => '>', 
        'lte' => '<=', 
        'lt' => '<',
        'eq' => '=',
        'neq' => '!=',
        'contains' => 'LIKE',
        'notContains' => "NOT LIKE",
        'startsWith' => "LIKE", 
        'endsWith' => "LIKE"
      }.freeze
      
      def filter_orders(searched_orders = "", is_from_update = false)
        filters = JSON.parse(@params[:filters])
        limit = get_limit_or_offset('limit')
        offset = get_limit_or_offset('offset')

        filtered_filters = filters.reject { |filter| filter['name'] == 'Status' }
        filters = @params[:filter].to_s.split(",").map(&:downcase) if filters[3]["value"]
        search_orders_ids = searched_orders["orders"].pluck(:id) if searched_orders.present?
        search_orders_ids = search_orders_ids.join(', ') if search_orders_ids.present?
        search_query = filters.include?("all") && filtered_filters.pluck("value").all?(&:blank?) ? " WHERE id IN (#{search_orders_ids})" : " AND id IN (#{search_orders_ids})"
        search_query = "" if search_orders_ids.blank?
        final_order = (filtered_order(filtered_filters, filters).to_sql + search_query)
        filtered_count = ActiveRecord::Base.connection.execute("SELECT COUNT(*) FROM (#{final_order}) AS subquery").first[0]
        if !is_from_update
          final_order = Order.find_by_sql(final_order + get_query_limit_offset(limit, offset))
        else
          final_order = Order.find_by_sql(final_order)
        end

        [final_order, filtered_count]
      end


      private

      def filtered_order(filtered_filters, filters)
        Order.filter_all_status(filters)
             .filter_by_qty(OPERATORS_MAP[get_operator_from_filter(4, filtered_filters)], filtered_filters[4]["value"])
             .filter_by_increment_id(OPERATORS_MAP[get_operator_from_filter(0, filtered_filters)], map_value(filtered_filters[0]["operator"], filtered_filters[0]["value"]))
             .filter_by_store(OPERATORS_MAP[get_operator_from_filter(1, filtered_filters)], map_value(filtered_filters[1]["operator"], filtered_filters[1]["value"]))
             .filter_by_notes_internal(OPERATORS_MAP[get_operator_from_filter(2, filtered_filters)], map_value(filtered_filters[2]["operator"], filtered_filters[2]["value"]))
             .filter_by_date(OPERATORS_MAP[get_operator_from_filter(3, filtered_filters)], map_value(filtered_filters[3]["operator"], filtered_filters[3]["value"]))
             .filter_by_recipient(OPERATORS_MAP[get_operator_from_filter(5, filtered_filters)], map_value(filtered_filters[5]["operator"], filtered_filters[5]["value"]))
             .filter_by_custom_field_one(OPERATORS_MAP[get_operator_from_filter(6, filtered_filters)], map_value(filtered_filters[6]["operator"], filtered_filters[6]["value"]))
             .filter_by_custom_field_two(OPERATORS_MAP[get_operator_from_filter(7, filtered_filters)], map_value(filtered_filters[7]["operator"], filtered_filters[7]["value"]))
             .filter_by_tracking_num(OPERATORS_MAP[get_operator_from_filter(8, filtered_filters)], map_value(filtered_filters[8]["operator"], filtered_filters[8]["value"]))
             .filter_by_country(OPERATORS_MAP[get_operator_from_filter(9, filtered_filters)], map_value(filtered_filters[9]["operator"], filtered_filters[9]["value"]))
             .filter_by_city(OPERATORS_MAP[get_operator_from_filter(10, filtered_filters)], map_value(filtered_filters[10]["operator"], filtered_filters[10]["value"]))
             .filter_by_email(OPERATORS_MAP[get_operator_from_filter(11, filtered_filters)], map_value(filtered_filters[11]["operator"], filtered_filters[11]["value"]))
             .filter_by_tote(OPERATORS_MAP[get_operator_from_filter(12, filtered_filters)], map_value(filtered_filters[12]["operator"], filtered_filters[12]["value"]))
             .within_date_range(date_range(filtered_filters), filtered_filters[3]["operator"])
             .within_number_range(number_range(filtered_filters))
      end

      def date_range(filters)
        start_date = filters[3]['value'].is_a?(Hash) ? filters[3]['value']['start'] : nil
        end_date = filters[3]['value'].is_a?(Hash) ? filters[3]['value']['end'] : nil

        { start_date: start_date, end_date: end_date }
      end

      def number_range(filters)
        start_value = filters[4]['value'].is_a?(Hash) ? filters[4]['value']['start'] : nil
        end_value = filters[4]['value'].is_a?(Hash) ? filters[4]['value']['end'] : nil

        { start_value: start_value, end_value: end_value }
      end

      def get_operator_from_filter(index, filters)
        filter = filters[index]
        filter ? filter["operator"] : nil
      end

      def map_value(key, value)
        return nil if value.blank? || !value
        value_map = {
          'contains' => "%#{value}%",
          'notContains' => "%#{value}%",
          'eq' => value,
          'afterOrOn' => value,
          'beforeOrOn' => value,
          'neq' => value,
          'after' => value,
          'before' => value,
          'inrange' => value,
          'notinrange' => value,
          'startsWith' => "#{value}%", 
          'endsWith' => "%#{value}"
        } 
      
        value_map[key]
      end
      
    end
  end
end
