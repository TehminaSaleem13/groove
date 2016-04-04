module ProductsService
  class FindProducts < ProductsService::ServiceInit
    attr_accessor :params, :sort_key, :sort_order, :status_filter, :limit,
                  :offset, :query_add, :kit_query, :status_filter_text, :is_kit,
                  :supported_kit_params

    def initialize(*args)
      @params = args[0]
      @query_add = ''
      @kit_query = ''
      @status_filter_text = ''
      @supported_kit_params = ['0', '1', '-1']
    end

    def call
      setup_query_params
      # HACK: to bypass for now and enable client development
      # @sort_key = 'name' if @sort_key == 'sku'
      if @sort_key.in? expected_sort_keys
        sorting_with_expected_sort_keys
      else
        @products = Product.order(@sort_key + ' ' + @sort_order)
        default_query
      end

      query_if_no_products
      @products
    end

    private

    def setup_query_params
      # Get passed in parameter variables if they are valid.
      set_sort_key
      set_sort_order
      set_limit
      set_offset
      set_is_kit
      set_status_filter
    end

    def expected_sort_keys
      %w(
        sku store_type barcode location_primary location_secondary
        location_tertiary location_name available_inv cat
      )
    end

    def supported_sort_keys
      %w(
        updated_at name sku status barcode location_primary location_secondary
        location_tertiary location_name cat available_inv store_type
      )
    end

    def supported_order_keys
      %w(ASC DESC) # Caps letters only
    end

    def supported_status_filters
      %w(all active inactive new)
    end

    def set_limit
      p_limit = params[:limit]
      @limit = p_limit.to_i > 0 ? p_limit.to_i : 10
    end

    def set_offset
      p_offset = params[:offset]
      @offset = p_offset.to_i >= 0 ? p_offset.to_i : 0
    end

    def set_sort_key
      p_sort = params[:sort]
      @sort_key = supported_sort_keys_contains(p_sort) ? p_sort : 'updated_at'
    end

    def supported_sort_keys_contains(key)
      supported_sort_keys.include?(key.to_s)
    end

    def set_sort_order
      p_order = params[:order]
      @sort_order = supported_order_keys_contains(p_order) ? p_order : 'DESC'
    end

    def supported_order_keys_contains(key)
      supported_order_keys.include?(key.to_s)
    end

    def set_status_filter
      p_filter = params[:filter]
      @status_filter = if supported_status_filters_contains(p_filter)
                         p_filter
                       else
                         'active'
                       end
    end

    def supported_status_filters_contains(filter)
      supported_status_filters.include?(filter.to_s)
    end

    def set_is_kit
      p_is_kit = params[:is_kit]
      @is_kit = supported_kit_params_contains(p_is_kit) ? p_is_kit.to_i : 0
    end

    def supported_kit_params_contains(kit_param)
      supported_kit_params.include?(kit_param.to_s)
    end

    def set_kit_query
      return if @is_kit == -1
      @kit_query = ' WHERE products.is_kit=' + @is_kit.to_s
    end

    def set_query_add
      return if params[:select_all] || params[:inverted]
      @query_add += ' LIMIT ' + @limit.to_s + ' OFFSET ' + @offset.to_s
    end

    def set_status_filter_text
      return if status_filter == 'all'
      @status_filter_text = is_kit == '-1' ? ' WHERE ' : ' AND '
      @status_filter_text += " products.status='" + status_filter + "'"
    end

    def sorting_with_expected_sort_keys
      query = send("sort_by_#{@sort_key}")
      @products = Product.find_by_sql(query)
    end

    def sort_by_sku
      %(\
        SELECT products.* FROM products LEFT JOIN product_skus ON \
        (products.id = product_skus.product_id ) #{@kit_query}\
        #{@status_filter_text}GROUP BY product_id \
        ORDER BY product_skus.sku #{@sort_order}#{@query_add}
      )
    end

    def sort_by_store_type
      %(\
        SELECT products.* FROM products \
        LEFT JOIN stores ON (products.store_id = stores.id ) \
        #{@kit_query}#{@status_filter_text} \
        ORDER BY stores.name #{@sort_order}#{@query_add}
      )
    end

    def sort_by_barcode
      %(\
        SELECT products.* FROM products LEFT JOIN product_barcodes ON \
        (products.id = product_barcodes.product_id ) \
        #{@kit_query}#{@status_filter_text} \
        ORDER BY product_barcodes.barcode #{@sort_order}#{@query_add}
      )
    end

    def sort_by_location_primary
      %(\
        SELECT products.* FROM products \
        LEFT JOIN product_inventory_warehouses ON \
        ( products.id = product_inventory_warehouses.product_id ) \
        #{@kit_query}#{@status_filter_text} \
        ORDER BY product_inventory_warehouses.location_primary \
        #{@sort_order}#{@query_add}
      )
    end

    def sort_by_location_secondary
      %(\
        SELECT products.* FROM products \
        LEFT JOIN product_inventory_warehouses ON \
        ( products.id = product_inventory_warehouses.product_id ) \
        #{@kit_query}#{@status_filter_text} \
        ORDER BY product_inventory_warehouses.location_secondary \
        #{@sort_order}#{@query_add}
      )
    end

    def sort_by_location_tertiary
      %(\
        SELECT products.* FROM products \
        LEFT JOIN product_inventory_warehouses ON \
        ( products.id = product_inventory_warehouses.product_id ) \
        #{@kit_query}#{@status_filter_text} \
        ORDER BY product_inventory_warehouses.location_tertiary \
        #{@sort_order}#{@query_add}
      )
    end

    def sort_by_location_name
      %(\
        SELECT products.* FROM products \
        LEFT JOIN product_inventory_warehouses ON \
        ( products.id = product_inventory_warehouses.product_id )  \
        LEFT JOIN inventory_warehouses ON \
        (product_inventory_warehouses.inventory_warehouse_id = \
        inventory_warehouses.id ) \
        #{@kit_query}#{@status_filter_text} \
        ORDER BY inventory_warehouses.name #{@sort_order}#{@query_add}
      )
    end

    def sort_by_available_inv
      %(\
        SELECT products.* FROM products \
        LEFT JOIN product_inventory_warehouses ON \
        ( products.id = product_inventory_warehouses.product_id ) \
        #{@kit_query}#{@status_filter_text} \
        ORDER BY product_inventory_warehouses.available_inv \
        #{@sort_order}#{@query_add}
      )
    end

    def sort_by_cat
      %(\
        SELECT products.* FROM products \
        LEFT JOIN product_cats ON \
        ( products.id = product_cats.product_id ) \
        #{@kit_query}#{@status_filter_text} \
        ORDER BY product_cats.category #{@sort_order}#{@query_add}
      )
    end

    def query_if_no_products
      return unless @products.length == 0
      @products = Product.where(1)
      default_query
    end

    def default_query
      filter_by_kit
      filter_by_status
      filter_by_limit_offset
    end

    def filter_by_kit
      @products = @products.where(is_kit: @is_kit.to_s) unless @is_kit.eql?(-1)
    end

    def filter_by_status
      return if @status_filter.eql?('all')
      @products = @products.where(status: @status_filter)
    end

    def filter_by_limit_offset
      return if select_all_and_inverted?
      @products = @products.limit(limit).offset(@offset)
    end

    def select_all_and_inverted?
      params[:select_all] || params[:inverted]
    end
  end
end
