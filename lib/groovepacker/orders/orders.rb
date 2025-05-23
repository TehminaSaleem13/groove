# frozen_string_literal: true

module Groovepacker
  module Orders
    class Orders < Groovepacker::Orders::Base
      include ScanPack::Utilities::ProductScan::SingleProductType
      include ScanPack::Utilities::ProductScan::IndividualProductType
      def update_orders_list(order)
        unless accepted_data.key?(@params[:var])
          set_status_and_message(false, 'Unknown field', ['&', 'error_msg'])
          return @result
        end
        if @params[:var] == 'status'
          order_status = order.status
          check = order.order_items.map(&:qty).include?(0) && order.order_items.sum(&:removed_qty).zero?
          if check
            set_status_and_message(false, 'Only orders containing Active items can be Awaiting', ['&', 'error_msg'])
          else
            order.status = @params[:value]
          end
          if @params[:value] == 'scanned'
            order.order_items.each do |order_item|
              order_item.scanned_status = 'scanned'
              order_item.save
            end
            add_activity(order, @current_user.name)
          else
            order.save
            retain_items = !ScanPackSetting.last.remove_skipped && order_status == 'scanned' && @params[:value] == 'awaiting'
            if retain_items
              order.order_items.where('skipped_qty != 0').each do |order_item|
                order_item.update(qty: order_item.qty + order_item.skipped_qty, skipped_qty: 0)
              end
            end
            order.scanned_by_status_change = false
            order.addactivity("Order Manually Moved To #{order.status.capitalize} Status", @current_user.name)
          end
        elsif @params[:var] == 'ordernum'
          order.increment_id = @params[:value]
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
        @result
      end

      def add_activity(order, username)
        order.scanned_on = Time.current
        order.scanned_by_status_change = true
        order.packing_user_id = User.find_by_username(username).try(:id)
        order.addactivity('Order Manually Moved To Scanned Status', username)
      end

      def add_by_passed_activity(order, sku, on_ex)
        order.addactivity('Product instructions confirmation for SKU: ' + sku.to_s + ' bypassed ', @current_user.name, on_ex, 'by_passed')
      end

      def generate_pick_list(orders)
        @orders = orders
        @pick_list = []
        @depends_pick_list = []

        @orders.each do |order|
          add_order_items_to_pick_list(order, order.store)
        end
        sort_pick_list
        sort_depends_pick_list

        [@result, @pick_list, @depends_pick_list]
      end

      def remove_item_from_order
        @orderitem = OrderItem.includes(%i[order product order_item_boxes order_item_kit_products order_item_boxes order_item_scan_times]).where(id: @params[:orderitem])
        if @orderitem.blank?
          set_status_and_message(false, 'Could not find order item', ['&', 'push'])
          return @result
        end

        remove_item_if_not_scanned
        @result
      end

      def remove_item_qty_from_order
        @orderitem = OrderItem.includes(%i[order product order_item_boxes order_item_kit_products order_item_boxes order_item_scan_times]).where(id: @params[:orderitem]).first
        if @orderitem.blank?
          set_status_and_message(false, 'Could not find order item', ['&', 'push'])
          return @result
        end
        item = @orderitem.order.get_unscanned_items(limit: nil).find { |item| item["order_item_id"] == @params["orderitem"].first.to_i }
        return unless item.present?
        
        @single_order = @orderitem.order
        qty = item['product_type'] == 'individual' ? remove_kit_item_from_order(item['child_items'].first, true) : remove_skippable_product(item)
        @orderitem.order.addactivity("QTY #{qty} of SKU #{@orderitem['product_type'] == 'individual' ? @orderitem['child_items'].first['sku'] : @orderitem['sku']} was removed using the REMOVE barcode", @current_user.try(:username))
      end

      def add_item_to_order
        @order = Order.find(@params[:id])
        if @order.status == 'scanned'
          set_status_and_message(false, 'Order has already been scanned and cannot be modified', ['push'])
          return
        end

        @products = begin
                      Product.find(@params[:productids])
                    rescue StandardError
                      []
                    end
        add_if_products_exist
        @result
      end

      def update_order_item
        @orderitem = OrderItem.find_by_id(@params[:orderitem])
        if @orderitem.nil?
          set_status_and_message(false, 'Could not find order item', ['&', 'push'])
          return @result
        end

        if @params.key?('qty')
          update_orderitem_quantity
          @orderitem.order.update_order_status
        else
          update_orderitem_barcode_status
        end
        @result
      end

      def get_common_parameters
        sort_key = get('sort_key', 'updated_at')
        sort_order = get('sort_order', 'DESC')
        limit = get_limit_or_offset('limit') # Get passed in parameter variables if they are valid.
        offset = get_limit_or_offset('offset')
        status_filter = get('status_filter', 'awaiting')
        status_filter_text = ''
        query_add = get_query_limit_offset(limit, offset)

        # overrides
        sort_key = set_final_sort_key(sort_order, sort_key)

        status_filter_text = " WHERE orders.status='" + status_filter + "'" unless status_filter.in?(%w[all partially_scanned])
        status_filter_text = " JOIN order_items ON order_items.order_id = orders.id WHERE orders.status='awaiting' AND order_items.scanned_qty != 0 " if status_filter == 'partially_scanned'

        [sort_key, sort_order, limit, offset, status_filter, status_filter_text, query_add]
      end

      def do_getorders
        sort_key, sort_order, limit, offset, status_filter, status_filter_text, query_add = get_common_parameters

        orders = get_sorted_orders(sort_key, sort_order, limit, offset, query_add, status_filter_text, status_filter)
        orders
      end

      private

      def get_sorted_orders(sort_key, sort_order, limit, offset, query_add, status_filter_text, status_filter)
        # HACK: to bypass for now and enable client development
        # sort_key = 'updated_at' if sort_key == 'sku'
        if sort_key == 'store_name'
          orders = Order.find_by_sql("SELECT orders.* FROM orders LEFT JOIN stores ON orders.store_id = stores.id #{status_filter_text} ORDER BY stores.name #{sort_order} #{query_add}")
          preloader(orders)
        elsif sort_key == 'itemslength'
          status_filter_text = " WHERE orders.status='awaiting' AND order_items.scanned_qty != 0 " if status_filter == 'partially_scanned'
          orders = Order.find_by_sql("SELECT orders.*, sum(order_items.qty) AS count FROM orders LEFT JOIN order_items ON (order_items.order_id = orders.id) #{status_filter_text} GROUP BY orders.id ORDER BY count #{sort_order} #{query_add}")
          preloader(orders)
        elsif sort_key == 'tote'
          orders = Order.find_by_sql("SELECT orders.* FROM orders LEFT JOIN totes ON totes.order_id = orders.id #{status_filter_text} ORDER BY totes.name #{sort_order} #{query_add}")
          preloader(orders)
        else
          orders = if @params[:oldest_unscanned]
            base_orders = Order.awaiting_without_partially_scanned.includes(:tote, :store, :order_tags)
            filtered_orders = ScanPackSetting.first.requires_assigned_orders ? base_orders.joins(:assigned_user).where(users: { username: @current_user.username }) : base_orders
            filtered_orders.order("#{sort_key} #{sort_order}")
          else
            Order.includes(:tote, :store, :order_tags).order("#{sort_key} #{sort_order}")
          end
          # orders = @params[:app] ? orders.not_locked_or_recent(@current_user.id) : orders
          orders = orders.where(status: status_filter) unless status_filter.in?(%w[all partially_scanned])
          orders = orders.partially_scanned if status_filter == 'partially_scanned'
          orders = orders.limit(limit).offset(offset) unless @params[:select_all] || @params[:inverted]
        end
        orders
      end

      def get_filtered_sorted_orders(sort_key, sort_order, limit, offset, filtered_orders)
        # orders = Order.where(id: filtered_orders.pluck(:id))
        orders = filtered_orders.includes(:tote, :store, :order_tags).order("#{sort_key} #{sort_order}")
        orders = orders.limit(limit).offset(offset) unless @params[:select_all] || @params[:inverted]
        orders
      end

      def preloader(orders)
        ActiveRecord::Associations::Preloader.new.preload(orders, %i[tote store order_tags])
      end

      def update_list_for_not_scanned(order)
        if @params[:var] == 'recipient'
          arr = @params[:value].blank? ? [] : @params[:value].split(' ')
          order.firstname = arr.shift
          order.lastname = arr.join(' ')
        elsif @params[:var] == 'notes_from_packer' || @current_user.can?('add_edit_order_items')
          key = accepted_data[@params[:var]]
          order[key] = @params[:value]
        else
          set_status_and_message(false, 'Insufficient permissions', ['&', 'error_msg'])
        end
        order
      end

      def update_orderitem_quantity
        if Order::SOLD_STATUSES.include? @orderitem.order.status
          set_status_and_message(false, "Scanned Orders item quantities can't be changed", ['&', 'push'])
        else
          product = @orderitem.product
          sku = begin
                    product.product_skus.first.sku
                rescue StandardError
                  nil
                  end
          if @params[:qty] > (@orderitem.qty + @orderitem.skipped_qty)
            value = @params[:qty] - (@orderitem.qty + @orderitem.skipped_qty)
            @orderitem.order.addactivity('Item with sku ' + sku.to_s + " QTY increased by #{value}", @current_user.name, @params[:on_ex])
          else
            value = (@orderitem.qty + @orderitem.skipped_qty) - @params[:qty]
            @orderitem.order.addactivity('Item with sku ' + sku.to_s + " QTY decreased by #{value} ", @current_user.name, @params[:on_ex])
          end
          @orderitem.skipped_qty = 0
          if @orderitem.scanned_status == 'scanned' && @params[:qty] > @orderitem.qty
            @orderitem.scanned_status = 'partially_scanned'
            if @orderitem.order_item_kit_products.count > 0
              @orderitem.order_item_kit_products.each do |o|
                o.scanned_status = 'partially_scanned'
                o.save
              end
            end
          end

          @orderitem.qty = @params[:qty]

        end
        return if @orderitem.save

        set_status_and_message(false, 'Could not update order item ', ['&', 'push'])
      end

      def update_orderitem_barcode_status
        @orderitem.is_barcode_printed = true
        unless @orderitem.save
          set_status_and_message(false, ' Could not update order item', ['&', 'push'])
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
        sku = begin
                  product.product_skus.first.sku
              rescue StandardError
                nil
                end

        if item.remove_order_item_kit_products && item.destroy
          item.order.update_order_status
          item.order.addactivity('Item with sku ' + sku.to_s + ' removed', @current_user.name, @platform)
        else
          set_status_and_message(false, 'Removed items from order failed', ['&', 'push'])
        end
      end

      def add_if_products_exist
        if @products.blank?
          set_status_and_message(false, 'Could not find any Item', ['&', 'push'])
          return
        end

        @products.each do |product|
          if @order.order_items.exists?(product_id: product.id)
            increase_qty_scanned(product)
          else
            add_single_item(product)
          end
        end

        @order.update_order_status
        @order.touch
        return if @order.save

        set_status_and_message(false, 'Adding item to order failed', ['&', 'push'])
      end

      def add_single_item(product)
        orderitem = init_order_item(product)
        @order.order_items << orderitem

        if orderitem.save
          add_product_sku(product)
        end
      end

      def increase_qty_scanned(product)
        orderitem = first_order_item(product)
        orderitem.qty += 1
        orderitem.scanned_qty += 1 if @params[:add_to_scanned_list].present?
        orderitem.scanned_status = 'partially_scanned'
        if orderitem.order_item_kit_products.present?
          orderitem.order_item_kit_products.each do |kit_product|
            kit_product.scanned_status = 'partially_scanned'
            kit_product.save
          end
        end
        if orderitem.save
          add_product_sku(product)
        end
      end

      def first_order_item(product)
       order = @order.order_items.where(product_id: product.id)
       order.first
      end

      def add_product_sku(product)
        product_sku = begin
                        product.product_skus.first.sku
                      rescue StandardError
                        nil
                      end
        @order.addactivity('Item with sku ' + product_sku.to_s + ' added', @current_user.name, @platform)
      end

      def init_order_item(product)
        qty = 1
        qty = @params[:qty] unless @params[:qty].blank? && @params[:qty].to_i > -1

        orderitem = OrderItem.new
        orderitem.name = product.name
        orderitem.price = @params[:price]
        orderitem.qty = qty.to_i
        if @params[:add_to_scanned_list].present?
          orderitem.scanned_status = 'scanned'
          orderitem.scanned_qty = qty
        end
        orderitem.added_count = qty.to_i
        orderitem.row_total = @params[:price].to_f * @params[:qty].to_f
        orderitem.product_id = product.id
        orderitem
      end

      def sort_depends_pick_list
        return if @depends_pick_list.empty?

        @depends_pick_list = @depends_pick_list.sort_by do |h|
          h['individual'] = sort_individual(h) unless h['individual'].empty?
          if h['single'].empty? || h['single'][0]['primary_location'].blank?
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
        return if @pick_list.empty?

        @pick_list = @pick_list.sort_by do |h|
          h['primary_location'].blank? ? '' : h['primary_location']
        end
      end

      def add_order_items_to_pick_list(order, store)
        inventory_warehouse_id = 0
        inventory_warehouse_id = store.inventory_warehouse_id if store.present? && store.inventory_warehouse.present?
        @single_pick_list_obj = Groovepacker::PickList::SinglePickListBuilder.new
        @individual_pick_list_obj = Groovepacker::PickList::IndividualPickListBuilder.new
        @depends_pick_list_obj = Groovepacker::PickList::DependsPickListBuilder.new

        order.order_items.each do |order_item|
          add_single_item_to_list(order_item, inventory_warehouse_id)
        end
      end

      def add_single_item_to_list(order_item, inv_warehouse_id)
        product = order_item.product
        return if product.nil? || product.is_intangible

        # for single products which are not kit
        if product.is_kit == 0 || product.kit_parsing == 'single'
          @pick_list = @single_pick_list_obj.build(
            order_item.qty, product, @pick_list, inv_warehouse_id
          )
        elsif product.kit_parsing == 'individual'
          @pick_list = @individual_pick_list_obj.build(
            order_item.qty, product, @pick_list, inv_warehouse_id
          )
        elsif product.kit_parsing == 'depends'
          @depends_pick_list = @depends_pick_list_obj.build(
            order_item.qty, product, @depends_pick_list, inv_warehouse_id
          )
        end
      end
    end
  end
end
