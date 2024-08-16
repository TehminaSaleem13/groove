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
        filters = JSON.parse(@params[:filters].is_a?(Array) ? @params[:filters].to_json : @params[:filters])
        limit = get_limit_or_offset('limit')
        offset = get_limit_or_offset('offset')

        filtered_filters = filters.reject { |filter| filter['name'] == 'Status' }
        filters = @params[:filter].to_s.split(",").map(&:downcase) if filters[3]["value"]
        search_orders_ids = searched_orders["orders"].pluck(:id) if searched_orders.present?
        search_orders_ids = search_orders_ids.join(', ') if search_orders_ids.present?
        search_query = filters.include?("all") && filtered_filters.pluck("value").all?(&:blank?) ? " WHERE id IN (#{search_orders_ids})" : " AND id IN (#{search_orders_ids})"
        search_query = "" if search_orders_ids.blank?
        final_order = (filtered_order(filtered_filters, filters).to_sql + search_query)
        results = ActiveRecord::Base.connection.execute("SELECT id FROM (#{final_order}) AS subquery")
        data = results.map { |row| row }
        filtered_count = ActiveRecord::Base.connection.execute("SELECT COUNT(*) FROM (#{final_order}) AS subquery").first[0]
        if !is_from_update
          final_order = Order.find_by_sql(final_order + get_query_limit_offset(limit, offset))
        else
          final_order = Order.find_by_sql(final_order)
        end
        tags = calculate_tags_count(data.flatten)

        [final_order, filtered_count, tags]
      end


      private

      def calculate_tags_count(data)
        order_ids = Order.where(id: data)
        tags = OrderTag.all.uniq
        tag_names = tags.pluck(:name)

        tags_in_orders = OrderTag.joins(:orders)
        .where(orders: { id: order_ids }, name: tag_names)
        .group(:name)
        .pluck('order_tags.name, COUNT(orders.id) as order_count')

        order_tags_hash = tags_in_orders.map do |name, count|
          { name: name, order_count: count }
        end
        
        total_order_count = order_ids.size
        tags_not_present_counts = tag_names.uniq.each_with_object([]) do |tag_name, array|
          orders_with_tag_count = tags_in_orders.find { |name, _| name == tag_name }&.last || 0
        
          count_not_present = total_order_count - orders_with_tag_count
        
          if count_not_present > 0
            array << { name: tag_name, not_present_in_order_count: count_not_present }
          end
        end

        {
          present: order_tags_hash,
          not_present: tags_not_present_counts
        }
      end

      def filtered_order(filtered_filters, filters)
        sort_key, sort_order, limit, offset, status_filter, status_filter_text, query_add = get_parameters

        Order.filtered_sorted_orders(@params[:sort], sort_order, limit, offset, status_filter, status_filter_text, query_add, @params)
             .filter_all_status(filters)
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
             .within_number_range(number_range(filtered_filters), @params[:sort])
             .with_tags(@params[:tags_name], @params[:filterIncludedTags])
             .without_tags(@params[:tags_name], @params[:filterIncludedTags])
             .check_date_range(@params[:dateRange])
             .filter_by_last_days(@params[:dateValue])
      end
      
      def get_parameters
        sort_key = get('sort_key', 'updated_at')
        sort_order = get('sort_order', 'DESC')
        limit = get_limit_or_offset('limit')
        offset = get_limit_or_offset('offset')
        status_filter = get('status_filter', 'awaiting')
        status_filter_text = ''
        query_add = get_query_limit_offset(limit, offset)

        status_filter_text = " WHERE orders.status='" + status_filter + "'" unless status_filter.in?(%w[all partially_scanned])
        status_filter_text = " JOIN order_items ON order_items.order_id = orders.id WHERE orders.status='awaiting' AND order_items.scanned_qty != 0 " if status_filter == 'partially_scanned'

        [sort_key, sort_order, limit, offset, status_filter, status_filter_text, query_add]
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
