# frozen_string_literal: true

module Groovepacker
  module Orders
    class OrdersSearch < Groovepacker::Orders::Base
      def do_search(results_only = true, without_limit = false)
        sort_key = get('sort_key', 'updated_at')
        sort_order = get('sort_order', 'DESC')
        limit = get_limit_or_offset('limit') # Get passed in parameter variables if they are valid.
        offset = get_limit_or_offset('offset')
        sort_key = set_final_sort_key(sort_order, sort_key)
        sort_key = 'store_type' if sort_key == 'store_name'
        search = ActiveRecord::Base.connection.quote('%' + @params[:search] + '%')
        exact_search = ActiveRecord::Base.connection.quote(@params[:search])
        base_query = get_base_query(search, exact_search, sort_key, sort_order)
        query_add = get_query_limit_offset(limit, offset)
        result_rows = if without_limit
                        Order.find_by_sql(base_query)
                      else
                        Order.find_by_sql(base_query + query_add)
                      end
        ActiveRecord::Associations::Preloader.new.preload(result_rows, %i[order_items store order_tags])
        get_search_result(results_only, result_rows, base_query)
      end

      private

      def get_base_query(search, exact_search, sort_key, sort_order)
        if @params['product_search_toggle'] == 'true'
          base_query = "Select orders.*, sum(order_items.qty) AS itemslength from orders LEFT JOIN stores ON (orders.store_id = stores.id) LEFT JOIN order_items ON (order_items.order_id = orders.id) LEFT JOIN products ON (products.id = order_items.product_id) LEFT JOIN product_skus ON (products.id = product_skus.product_id) LEFT JOIN product_barcodes ON (products.id = product_barcodes.product_id) WHERE if ((select count(*) from orders where increment_id = #{exact_search})>0,increment_id = #{exact_search} ,increment_id like #{search} OR tracking_num LIKE '#{'%' + @params[:search]}' OR non_hyphen_increment_id like #{search} OR email like #{search} OR CONCAT(IFNULL(firstname,''),' ',IFNULL(lastname,'')) like #{search} OR postcode like #{search} OR custom_field_one like #{search} OR custom_field_two like #{search} OR notes_internal like #{search} OR tags like #{search} OR products.name like #{search} OR product_skus.sku like #{search} OR product_barcodes.barcode like #{search} OR stores.name like #{search} ) GROUP BY orders.id Order BY #{sort_key} #{sort_order}"
        else
          # TODO: include sku and storename in search as well in future.
          base_query = "SELECT orders.*, SUM(order_items.qty) AS itemslength FROM orders LEFT JOIN stores ON (orders.store_id = stores.id) LEFT JOIN order_items ON (order_items.order_id = orders.id) WHERE IF ((SELECT COUNT(*) FROM orders WHERE increment_id = #{exact_search}) > 0, increment_id = #{exact_search}, LOWER(increment_id) LIKE LOWER(#{search}) OR LOWER(tracking_num) LIKE LOWER('#{'%' + @params[:search]}') OR LOWER(non_hyphen_increment_id) LIKE LOWER(#{search}) OR LOWER(email) LIKE LOWER(#{search}) OR CONCAT(IFNULL(firstname,''),' ',IFNULL(lastname,'')) LIKE LOWER(#{search}) OR LOWER(postcode) LIKE LOWER(#{search}) OR LOWER(custom_field_one) LIKE LOWER(#{search}) OR LOWER(custom_field_two) LIKE LOWER(#{search}) OR LOWER(notes_internal) LIKE LOWER(#{search}) OR LOWER(tags) LIKE LOWER(#{search}) OR LOWER(stores.name) LIKE LOWER(#{search}) OR LOWER(increment_id) = LOWER(#{exact_search})) GROUP BY orders.id ORDER BY #{sort_key} #{sort_order}"
        end
        base_query
      end

      def get_search_result(results_only, result_rows, base_query)
        if results_only
          result = result_rows
        else
          result = { 'orders' => result_rows }
          # result['count'] = order_count
          result['count'] = Order.count_by_sql('SELECT COUNT(*) as count from (' + base_query + ') as tmp_order')
        end
        result
      end
    end
  end
end
