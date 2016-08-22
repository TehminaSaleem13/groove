module Groovepacker
  module Orders
    class OrdersSearch < Groovepacker::Orders::Base

      def do_search(results_only = true)
        sort_key = get('sort_key', 'updated_at')
        sort_order = get('sort_order', 'DESC')
        limit = get_limit_or_offset('limit') # Get passed in parameter variables if they are valid.
        offset = get_limit_or_offset('offset')
        sort_key = set_final_sort_key(sort_order, sort_key)
        search = ActiveRecord::Base::sanitize('%'+@params[:search]+'%')
        base_query = get_base_query(search, sort_key, sort_order)
        query_add = get_query_limit_offset(limit, offset)
        result_rows = Order.find_by_sql(base_query + query_add)
        ActiveRecord::Associations::Preloader.new(result_rows, [:order_items, :store, :order_tags]).run
        return get_search_result(results_only, result_rows, base_query)
      end

      private
      def get_base_query(search, sort_key, sort_order)
        if @params["product_search_toggle"] == "true"
          base_query = "Select orders.*, sum(order_items.qty) AS itemslength from orders LEFT JOIN stores ON (orders.store_id = stores.id) LEFT JOIN order_items ON (order_items.order_id = orders.id) LEFT JOIN products ON (products.id = order_items.product_id) LEFT JOIN product_skus ON (products.id = product_skus.product_id) LEFT JOIN product_barcodes ON (products.id = product_barcodes.product_id) WHERE increment_id like #{search} OR non_hyphen_increment_id like #{search} OR email like #{search} OR CONCAT(IFNULL(firstname,''),' ',IFNULL(lastname,'')) like #{search} OR postcode like #{search} OR custom_field_one like #{search} OR custom_field_two like #{search} OR notes_internal like #{search} OR products.name like #{search} OR product_skus.sku like #{search} OR product_barcodes.barcode like #{search} GROUP BY orders.id Order BY #{sort_key} #{sort_order}"
        else
          #todo: include sku and storename in search as well in future.
          base_query = "Select orders.*, sum(order_items.qty) AS itemslength from orders LEFT JOIN stores ON (orders.store_id = stores.id) LEFT JOIN order_items ON (order_items.order_id = orders.id) WHERE increment_id like #{search} OR non_hyphen_increment_id like #{search} OR email like #{search} OR CONCAT(IFNULL(firstname,''),' ',IFNULL(lastname,'')) like #{search} OR postcode like #{search} OR custom_field_one like #{search} OR custom_field_two like #{search} OR notes_internal like #{search} GROUP BY orders.id Order BY #{sort_key} #{sort_order}"
        end
        base_query
      end

      def get_search_result(results_only, result_rows, base_query)
        if results_only
          result = result_rows
        else
          result = { 'orders' => result_rows }
          # result['count'] = order_count
          result['count'] = Order.count_by_sql('SELECT COUNT(*) as count from ('+ base_query+') as tmp_order')
        end
        result
      end
    end
  end
end
