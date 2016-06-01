module ProductsService
  class SearchProducts < ProductsService::Base
    attr_accessor :params, :result_only

    def initialize(*args)
      @params, @result_only = args
    end

    def call
      setup_query_params
      base_query = generate_base_query
      result_rows = Product.find_by_sql("#{base_query} #{@query_add}")
      preload_associations(result_rows)
      return result_rows if @result_only
      generate_result(result_rows, base_query)
    end

    private

    def setup_query_params
      @supported_order_keys = %w(ASC DESC) # Caps letters only

      set_sort_key
      set_sort_order

      # Get passed in parameter variables if they are valid.
      set_limit
      set_offset
      set_search_query
      @supported_kit_params = ['0', '1', '-1']

      set_is_kit

      set_kit_query
      set_query_add
    end

    def set_sort_key
      p_sort = params[:sort]
      @sort_key = supported_sort_keys_contains(p_sort) ? p_sort : 'updated_at'
    end

    def supported_sort_keys_contains(key)
      supported_sort_keys.include?(key.to_s)
    end

    def supported_sort_keys
      %w(
        updated_at name sku status barcode location_primary location_secondary
        location_tertiary location_name cat qty store_type
      )
    end

    def set_sort_order
      p_order = params[:order]
      @sort_order = supported_order_keys_contains(p_order) ? p_order : 'DESC'
    end

    def supported_order_keys_contains(key)
      @supported_order_keys.include?(key.to_s)
    end

    def set_limit
      p_limit = params[:limit]
      @limit = p_limit.to_i > 0 ? p_limit : '10'
    end

    def set_offset
      p_offset = params[:offset]
      @offset = p_offset.to_i >= 0 ? p_offset : '0'
    end

    def set_search_query
      @search = ActiveRecord::Base.sanitize("%#{params[:search]}%")
    end

    def set_is_kit
      p_is_kit = params[:is_kit]
      @is_kit = supported_kit_params_contains(p_is_kit) ? p_is_kit.to_i : 0
    end

    def supported_kit_params_contains(kit_param)
      @supported_kit_params.include?(kit_param.to_s)
    end

    def set_kit_query
      return if @is_kit == -1
      @kit_query = 'AND products.is_kit=' + @is_kit.to_s + ' '
    end

    def set_query_add
      return if select_all_or_inverted
      @query_add = ' LIMIT ' + @limit.to_s + ' OFFSET ' + @offset.to_s
    end

    def select_all_or_inverted
      params[:select_all] || params[:inverted]
    end

    def generate_base_query
      %(\
        SELECT  products.id as id, products.name as name, \
                products.type_scan_enabled as type_scan_enabled, \
                products.base_sku as base_sku, \
                products.click_scan_enabled as click_scan_enabled, \
                products.status as status, products.updated_at as updated_at, \
                product_skus.sku as sku, product_barcodes.barcode as barcode, \
                product_cats.category as cat, \
                product_inventory_warehouses.location_primary, \
                product_inventory_warehouses.location_secondary, \
                product_inventory_warehouses.location_tertiary, \
                product_inventory_warehouses.available_inv as qty, \
                inventory_warehouses.name as location_name, \
                stores.name as store_type, products.store_id as store_id \
        FROM products \
          LEFT JOIN product_skus ON (products.id = product_skus.product_id) \
          \
          LEFT JOIN product_barcodes ON \
            (product_barcodes.product_id = products.id) \
          \
          LEFT JOIN product_cats ON (products.id = product_cats.product_id) \
          \
          LEFT JOIN product_inventory_warehouses ON \
            (product_inventory_warehouses.product_id = products.id) \
          \
          LEFT JOIN inventory_warehouses ON \
            ( \
              product_inventory_warehouses.inventory_warehouse_id = \
                inventory_warehouses.id\
            ) \
          \
          LEFT JOIN stores ON (products.store_id = stores.id) \
          \
          WHERE\
          \(\
              products.name \
                like #{@search} OR product_barcodes.barcode \
                like #{@search} OR product_skus.sku \
                like #{@search} OR product_cats.category \
                like #{@search} OR \
                \(\
                    product_inventory_warehouses.location_primary like \
                      #{@search} \
                    OR \
                    product_inventory_warehouses.location_secondary like \
                      #{@search} \
                    OR \
                    product_inventory_warehouses.location_tertiary like \
                      #{@search} \
                \) \
            \) \
            #{@kit_query}\
          GROUP BY products.id ORDER BY #{@sort_key} #{@sort_order}
      )
    end

    def generate_result(result_rows, base_query)
      {
        'products' => result_rows,
        'count' =>  if select_all_or_inverted
                      result_rows.length
                    else
                      Product.count_by_sql(
                        %(SELECT count(*) as count from\(#{base_query}\) as tmp)
                      )
                    end
      }
    end
  end
end
