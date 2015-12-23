module Groovepacker
  module Orders
    class Orders < Groovepacker::Orders::Base
      
      def update_orders_list(order)
        unless accepted_data.has_key?(@params[:var])
          set_status_and_message(false, 'Unknown field', ['&', 'error_msg'])
          return @result
        end   

        if @params[:var] == 'status'
          order.status = @params[:value]
        elsif @params[:var] == 'notes' && @current_user.can?('create_edit_notes')
          order.notes_internal = @params[:value]
        elsif order.status != 'scanned'
          order = update_list_for_not_scanned(order)
        else
          set_status_and_message(false, 'Order has already been scanned and cannot be modified', ['&', 'error_msg'])
        end
        if @result['status'] && !order.save
          set_status_and_message(false, 'Could not save order info', ['&', 'error_msg'])
        end
        return @result
      end

      def add_edit_order_items(order)
        unless @current_user.can? 'add_edit_order_items'
          set_status_and_message(false, 'Couldn\'t rollback because you can not add or edit order items', ['push'])
          return @result
        end

        #Items
        destroy_object_if_not_defined(order.order_items, @params[:single]['items'], 'items')
        
        add_update_order_item(@params)
        
        #activity
        #As activities only get added, no updating or adding required
        activities = OrderActivity.where(:order_id => @params[:single]['basicinfo']['id'])
        destroy_object_if_not_defined(activities, @params[:single]['activities'], 'activities')
        return @result
      end

      def generate_pick_list(orders)
        @orders, @pick_list, @depends_pick_list = orders, [], []
        
        @orders.each do |order|
          add_order_items_to_pick_list(order, order.store)
        end
        sort_pick_list
        sort_depends_pick_list
        
        return @result, @pick_list, @depends_pick_list
      end

      def remove_item_from_order
        @orderitem = OrderItem.find(@params[:orderitem])
        if @orderitem.nil?
          set_status_and_message(false, "Could not find order item", ['&', 'push'])
          return @result
        end
        remove_item_if_not_scanned
        return @result
      end

      def add_item_to_order
        @order = Order.find(@params[:id])
        if @order.status == 'scanned'
          set_status_and_message(false, 'Order has already been scanned and cannot be modified', ['push'])
          return
        end
        @products = Product.find(@params[:productids])
        add_if_products_exist
        return @result
      end

      def update_order_item
        @orderitem = OrderItem.find_by_id(@params[:orderitem])
        if @orderitem.nil?
          set_status_and_message(false, "Could not find order item", ['&', 'push'])
          return @result
        end

        if @params.keys.include? ('qty')
          update_orderitem_quantity
          @orderitem.order.update_order_status
        else
          update_orderitem_barcode_status
        end
        return @result
      end

      def do_getorders
        sort_key = get('sort_key', 'updated_at')
        sort_order = get('sort_order', 'DESC')
        limit = get_limit_or_offset('limit') # Get passed in parameter variables if they are valid.
        offset = get_limit_or_offset('offset')
        status_filter = get('status_filter', 'awaiting')
        status_filter_text = ""
        query_add = get_query_limit_offset(limit, offset)
        
        #overrides
        sort_key = set_final_sort_key(sort_order, sort_key)

        unless status_filter == 'all'
          status_filter_text = " WHERE orders.status='"+status_filter+"'"
        end
        #todo status filters to be implemented
        orders = get_sorted_orders(sort_key, sort_order, limit, offset, query_add, status_filter_text, status_filter)
      end

      private
        def get_sorted_orders(sort_key, sort_order, limit, offset, query_add, status_filter_text, status_filter)
          #hack to bypass for now and enable client development
          #sort_key = 'updated_at' if sort_key == 'sku'
          if sort_key == 'store_name'
            orders = Order.find_by_sql("SELECT orders.* FROM orders LEFT JOIN stores ON orders.store_id = stores.id #{status_filter_text} ORDER BY stores.name #{sort_order} #{query_add}")
          elsif sort_key == 'itemslength'
            orders = Order.find_by_sql("SELECT orders.*, sum(order_items.qty) AS count FROM orders LEFT JOIN order_items ON (order_items.order_id = orders.id) #{status_filter_text} GROUP BY orders.id ORDER BY count #{sort_order} #{query_add}")
          else
            orders = Order.order("#{sort_key} #{sort_order}")
            orders = orders.where(:status => status_filter) unless status_filter == "all"
            orders = orders.limit(limit).offset(offset) unless @params[:select_all] || @params[:inverted]
          end
        end

        def update_list_for_not_scanned(order)
          if @params[:var] == "recipient"
            arr = @params[:value].blank? ? [] : @params[:value].split(' ')
            order.firstname = arr.shift
            order.lastname = arr.join(' ')
          elsif @params[:var] == 'notes_from_packer' || @current_user.can?('add_edit_order_items')
            key = accepted_data[@params[:var]]
            order[key] = @params[:value]
          else
            set_status_and_message(false, 'Insufficient permissions', ['&', 'error_msg'])
          end
          return order
        end

        def destroy_object_if_not_defined(objects_array, obj_params, type)
          return if objects_array.blank?
          ids = get_ids_array_from_params(obj_params, type)
          
          objects_array.each do |object|
            found_obj = false
            found_obj = true if ids.include?(object.id)
            object.destroy if found_obj
          end
        end

        def get_ids_array_from_params(obj_params, type=nil)
          if type=='items'
            ids = obj_params.map {|obj| obj['iteminfo']['id']} rescue []
          else
            ids = obj_params.map {|obj| obj["id"]} rescue []
          end
          return ids
        end

        def add_update_order_item(params)
          return if params[:single]['items'].blank?
          
          params[:single]['items'].each do |current_item|
            single_item = OrderItem.find_or_create_by_order_id_and_product_id(order.id, current_item['iteminfo']['product_id'])
            single_item = assign_values_to(single_item, current_item, 'item')
            update_product_list(current_item)
          end
        end

        def update_product_list(current_item)
          begin
            current_product = Product.find(current_item['iteminfo']['product_id'])
            values_to_update = { name: current_item['productinfo']['name'], is_skippable: current_item['productinfo']['is_skippable'], location: current_item['location'], sku: current_item['sku']}
            update_list(current_product, values_to_update)
          rescue Exception => e
          end
        end

        def update_list(current_product, values_to_update)
          values_to_update.each do |key, value|
            updatelist(current_product, "#{key.to_s}", value)
          end
        end

        def update_orderitem_quantity
          if Order::SOLD_STATUSES.include? @orderitem.order.status
            set_status_and_message(false, "Scanned Orders item quantities can't be changed", ['&', 'push'])
          else
            @orderitem.qty = @params[:qty]
          end
          return if @orderitem.save
          
          set_status_and_message(false, "Could not update order item ", ['&', 'push'])
        end

        def update_orderitem_barcode_status
          @orderitem.is_barcode_printed = true
          unless @orderitem.save
            set_status_and_message(false, " Could not update order item", ['&', 'push'])
            return
          end
          all_printed = @orderitem.order.order_items.map(&:is_barcode_printed).include?(false) ? false : true
          
          return unless all_printed
          
          @result['messages'].push('All item barcodes have now been printed. This order should now be ready to ship.')
        end

        def remove_item_if_not_scanned
          if @orderitem.first.order.status == 'scanned'
            set_status_and_message(false, 'Order has already been scanned and cannot be modified', ['push'])
            return @result
          end
          @orderitem.each do |item|
            remove_single_item(item)
          end
        end

        def remove_single_item(item)
          product = item.product
          sku = product.product_skus.first.sku rescue nil
          
          if item.remove_order_item_kit_products && item.destroy
            item.order.update_order_status
            item.order.addactivity("Item with sku " + sku.to_s + " removed", @current_user.name)
          else
            set_status_and_message(false, "Removed items from order failed", ['&', 'push'])
          end
        end

        def add_if_products_exist
          if @products.blank?
            set_status_and_message(false, "Could not find any Item", ['&', 'push'])
            return
          end
          
          @products.each do |product|
            add_single_item(product)
          end

          @order.update_order_status and return if @order.save
          set_status_and_message(false, "Adding item to order failed", ['&', 'push'])
        end

        def add_single_item(product)
          orderitem = init_order_item(product)
          @order.order_items << orderitem

          if orderitem.save
            product_sku = product.product_skus.first.sku rescue nil
            @order.addactivity("Item with sku " + product_sku.to_s + " added", @current_user.name)
          end
        end

        def init_order_item(product)
          qty = 1
          qty = @params[:qty] unless @params[:qty].blank? && @params[:qty].to_i > -1
          
          orderitem = OrderItem.new
          orderitem.name = product.name
          orderitem.price = @params[:price]
          orderitem.qty = qty.to_i
          orderitem.row_total = @params[:price].to_f * @params[:qty].to_f
          orderitem.product_id = product.id
          return orderitem
        end

        def sort_depends_pick_list
          return if @depends_pick_list.length == 0
          @depends_pick_list = @depends_pick_list.sort_by do |h|
            unless h['individual'].length == 0
              h['individual'] = sort_individual(h)
            end
            if h['single'].length == 0 || h['single'][0]['primary_location'].blank?
              ''
            else
              h['single'][0]['primary_location']
            end
          end
        end

        def sort_individual(h)
          individual = h['individual'].sort_by do |hash|
                         hash['primary_location'].blank? ? '' : hash['primary_location']
                       end
        end

        def sort_pick_list
          return if @pick_list.length == 0
          @pick_list = @pick_list.sort_by do |h|
            h['primary_location'].blank? ? '' : h['primary_location']
          end
        end

        def add_order_items_to_pick_list(order, store)
          inventory_warehouse_id = 0
          if store.present? && store.inventory_warehouse.present?
            inventory_warehouse_id = store.inventory_warehouse_id
          end
          @single_pick_list_obj = Groovepacker::PickList::SinglePickListBuilder.new
          @individual_pick_list_obj = Groovepacker::PickList::IndividualPickListBuilder.new
          @depends_pick_list_obj = Groovepacker::PickList::DependsPickListBuilder.new
          
          order.order_items.each do |order_item|
            add_single_item_to_list(order_item, inventory_warehouse_id)
          end
        end

        def add_single_item_to_list(order_item, inv_warehouse_id)
          product = order_item.product
          return if product.nil? && product.is_intangible
          
          # for single products which are not kit
          if product.is_kit == 0 || product.kit_parsing == 'single'
            @pick_list = @single_pick_list_obj.build(
              order_item.qty, product, @pick_list, inv_warehouse_id)
          elsif product.kit_parsing == 'individual'
            @pick_list = @individual_pick_list_obj.build(
              order_item.qty, product, @pick_list, inv_warehouse_id)
          elsif product.kit_parsing == 'depends'
            @depends_pick_list = @depends_pick_list_obj.build(
              order_item.qty, product, @depends_pick_list, inv_warehouse_id)
          end
        end
    end
  end
end
