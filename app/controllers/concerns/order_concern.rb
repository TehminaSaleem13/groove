module OrderConcern
  extend ActiveSupport::Concern
  
  included do
    before_filter :groovepacker_authorize!, except: [:import_shipworks]
    prepend_before_filter :initialize_result_obj, only: [:index, :importorders, :clear_exception, :record_exception, :import_all, :order_items_export, :update_order_list, :cancel_packing_slip, :duplicate_orders, :delete_orders, :change_orders_status, :generate_pick_list, :update, :show, :update_item_in_order, :rollback, :remove_item_from_order, :add_item_to_order, :search, :import, :cancel_import, :generate_packing_slip]
    before_filter :find_order, only: [:update, :show, :record_exception, :clear_exception, :update_order_list]
    before_filter :check_order_edit_permissions, only: [:add_item_to_order, :update_item_in_order, :remove_item_from_order]
    require 'csv'
    include OrdersHelper
    include ProductsHelper
    include SettingsHelper
    include ApplicationHelper
    include Groovepacker::Orders::ResponseMessage
  end
  
  private
    def list_selected_orders(sort_by_order_number = false)
      result = get_orders_list_for_selected(sort_by_order_number)
      result_rows = create_results_row(result)
      result_rows = result_rows.blank? ? [] : result_rows
      ids = result_rows.map {|p| p["id"]}
      orders = Order.where("id IN (?)", ids)
    end

    def get_orders_list_for_selected(sort_by_order_number = false)
      @params = params
      result =  if @params[:select_all] or @params[:inverted]
                  list_of_all_selected_or_inverted(sort_by_order_number)
                elsif @params[:orderArray].present?
                  list_of_orders_from_orderArray(sort_by_order_number)
                elsif @params[:id].present?
                  Order.find(@params[:id])
                else
                  list_of_orders_by_sort_order(sort_by_order_number)
                end
    end

    def list_of_all_selected_or_inverted(sort_by_order_number = false)
      if sort_by_order_number
        @params = @params.merge({:sort => 'ordernum', :order => 'ASC' })
      end
      result = @params[:search].blank? ? gp_orders_module.do_getorders : gp_orders_search.do_search
    end

    def list_of_orders_from_orderArray(sort_by_order_number = false)
      result = @params[:orderArray]
      if sort_by_order_number
        result = Order.where(:id => @params[:orderArray].map(&:values).flatten).order(:increment_id)
      end
      result
    end

    def list_of_orders_by_sort_order(sort_by_order_number = false)
      result = Order.where(:id => @params[:order_ids])
      result = result.order(:increment_id) if sort_by_order_number
      result
    end

    def create_results_row(result)
      return result unless params[:inverted] && params[:orderArray].present?

      not_in, result_rows = [], []

      params[:orderArray].each {|order| not_in.push(order['id']) }
      
      result.each do |single_order|
        result_rows.push(single_order) unless not_in.include? single_order['id']
      end
      result_rows
    end

    def get_orders_count
      count, all = {}, 0
      counts = Order.select('status,count(*) as count').where(:status => ['scanned', 'cancelled', 'onhold', 'awaiting', 'serviceissue']).group(:status)
      counts.each do |single|
        count[single.status] = single.count
        all += single.count
      end
      count = count.merge({ 'all' => all, 'search' => 0})
    end

    def cancel_packing(barcode)
      if barcode.nil?
        @result['error_messages'].push('No barcode found with the id.')
        return
      end
      barcode.cancel = true
      unless barcode.status =='in_progress'
        barcode.status = 'cancelled'
        begin
          the_delayed_job = Delayed::Job.find(barcode.delayed_job_id)
          the_delayed_job.destroy unless the_delayed_job.nil?
        rescue Exception => e
        end
      end

      if barcode.save
        @result['notice_messages'].push('Pdf generation marked for cancellation. Please wait for acknowledgement.')
      end
    end

    def import_result_messages(import_result)
      import_result[:messages].each { |msg| @result['messages'].push(msg) }

      @result.merge({ 'status' => !!import_result[:status],
                      'total_imported' => import_result[:total_imported],
                      'success_imported' => import_result[:success_imported],
                      'previous_imported' => import_result[:previous_imported] })
    end

    def change_order_status(order)
      # TODO: verify this status check
      # if (Order::SOLD_STATUSES.include?(@order.status) && Order::UNALLOCATE_STATUSES.include?(params[:status])) ||
      #   (Order::UNALLOCATE_STATUSES.include?(@order.status) && Order::SOLD_STATUSES.include?(params[:status]))
      #   puts "status change not allowed"
      if permitted_to_status_change(order)
        @result['error_messages'].push('This status change is not permitted.')
        return
      end
      order.status = params[:status]
      order.reallocate_inventory = params[:reallocate_inventory]
      return if order.save
      set_status_and_message(false, order.errors.full_messages)
    end

    def update_order_attrs
      return if @order.status == 'scanned'
      
      update_order_notes #Everyone can create notes from Packer

      if current_user.can?('add_edit_order_items')
        update_attrs_from_params
      elsif check_update_permissions
        set_status_and_message(false, 'You do not have enough permissions to edit the order', ['push'])
      end
    end

    def update_order_notes
      @order.notes_fromPacker = params[:order]['notes_fromPacker']
      
      if current_user.can?('create_edit_notes')
        @order.notes_internal = params[:order]['notes_internal']
        @order.notes_toPacker = params[:order]['notes_toPacker']
      elsif check_update_permissions(['notes_internal', 'notes_toPacker'])
        set_status_and_message(false, 'You do not have the permissions to edit notes', ['push'])
      end
    end

    def check_update_permissions(attrs_array = nil)
      attrs_array ||= order_update_attrs
      flag = false
      attrs_array.each do |attr|
        flag = true if @order[attr] != params[:order][attr]
        break if flag
      end
      return flag
    end

    def update_attrs_from_params
      attr_array = ['address_2', 'shipping_amount', 'order_total', 'weight_oz']
      order_update_attrs.each do |attr|
        unless attr_array.include?(attr)
          @order[attr] = params[:order][attr]
        else
          @order[attr] = params[:order][attr] unless params[:order][attr].nil?
        end
      end
    end

    def order_update_attrs
      ["firstname", "lastname", "company", "address_1", "address_2", "city", "state", "postcode", "country", "email", "increment_id", "order_placed_time", "customer_comments", "scanned_on", "tracking_num", "seller_id", "order_status_id", "order_number", "ship_name", "notes_from_buyer", "shipping_amount", "order_total", "weight_oz", "note_confirmation", "custom_field_one", "custom_field_two"]
    end

    def retrieve_order_items
      #Retrieve order items
      @result['order']['items'] = []
      @order.order_items.each do |orderitem|
        @result['order']['items'].push(retrieve_order_item(orderitem))
      end
      @result['order']['storeinfo'] = @order.store

      set_user_permissions #setting user permissions for add and remove items permitted
      set_unacknowledged_activities #Retrieve Unacknowledged activities
      add_a_nobody_user  #Add nobody user info if user info not available
      
      @result['order']['tags'] = @order.order_tags
    end

    def retrieve_order_item(orderitem)
      order_item = { 'iteminfo' => orderitem }
      product = Product.find_by_id(orderitem.product_id)
      if product.nil?
        order_item['productinfo'] = nil
        order_item['productimages'] = nil
      else
        product_available_inv = order_item_available_inv(product)
        product_attrs = init_product_attrs(product, product_available_inv)
        order_item = order_item.merge(product_attrs)
      end
      return order_item
    end

    def set_user_permissions
      @result['order'] = @result['order'].merge({ 'add_items_permitted' => current_user.can?('add_edit_order_items'),
                                                  'remove_items_permitted' => current_user.can?('add_edit_order_items'),
                                                  'activities' => @order.order_activities })
    end

    def set_unacknowledged_activities
      @result['order']['unacknowledged_activities'] = @order.unacknowledged_activities
      @result['order']['exception'] = @order.order_exception if current_user.can?('view_packing_ex')
      @result['order']['exception']['assoc'] =
        User.find(@order.order_exception.user_id) if current_user.can?('view_packing_ex') && !@order.order_exception.nil? && @order.order_exception.user_id !=0
    end

    def order_item_available_inv(product)
      available_inv = 0
      inv_warehouses = product.product_inventory_warehousess
      inv_warehouses.each {|iwh| available_inv += iwh.available_inv.to_i }
      return available_inv
    end

    def rollback_order_changes
      order = Order.find_by_id(params[:single]['basicinfo']['id'])
      if order.nil?
        set_status_and_message(false, "Wrong order id", ['&', 'push'])
        return
      end
      @result = gp_orders_exception.add_edit_order_items(order)
      @result = gp_orders_exception.edit_packing_execptions(order)
    end

    def generate_barcode_for_packingslip
      GenerateBarcode.where('updated_at < ?', 24.hours.ago).delete_all
      generate_barcode = GenerateBarcode.generate_barcode_for(@orders, current_user)
      delayed_job = GeneratePackingSlipPdf.delay(:run_at => 1.seconds.from_now).generate_packing_slip_pdf(@orders, current_tenant, @result, @page_height, @page_width, @orientation, @file_name, @size, @header, generate_barcode.id)
      generate_barcode.delayed_job_id = delayed_job.id
      generate_barcode.save
    end

    def add_a_nobody_user
      #add a user with name of nobody to display in the list
      dummy_user = User.new
      dummy_user.name = 'Nobody'
      dummy_user.id = 0
      @result['order']['users'] = User.all
      @result['order']['users'].unshift(dummy_user)

      user = @result['order']['users'].select {|user| user.id == @order.packing_user_id }.first
      user.name = "#{user.name} (Packing User)" if user
    end

    def find_order
      @order = Order.find_by_id(params[:id])
    end

    def initialize_result_obj
      @result = { 'status' => true, 'messages' => [], 'error_messages' => [], 'success_messages' => [], 'notice_messages' => [] }
    end

    def gp_orders_module
      Groovepacker::Orders::Orders.new(result: @result, params_attrs: params, current_user: current_user)
    end

    def gp_orders_search
      Groovepacker::Orders::OrdersSearch.new(result: @result, params_attrs: params, current_user: current_user)
    end

    def gp_orders_exception
      Groovepacker::Orders::OrdersException.new(result: @result, params_attrs: params, current_user: current_user)
    end
    def gp_orders_import
      Groovepacker::Orders::Import.new(result: @result, params_attrs: params, current_user: current_user)
    end

    def gp_orders_export
      Groovepacker::Orders::Export.new(result: @result, params_attrs: params, current_user: current_user)
    end

    def check_order_edit_permissions
      return if current_user.can? 'add_edit_order_items'
      set_status_and_message(false, 'You can not add or edit order items', ['&', 'push'])
    end

    def initiate_import_for_single_store
      store = Store.find_by_id(params[:store_id])
      Delayed::Job.where(queue: "importing_orders_"+current_tenant).destroy_all
      import_params = {tenant: current_tenant, store: store, import_type: params[:import_type], user: current_user, days: params[:days]}
      ImportOrders.new.import_order_by_store(import_params)
    end

    def permitted_to_status_change(order)
      (Order::SOLD_STATUSES.include?(order.status) && Order::UNALLOCATE_STATUSES.include?(params[:status])) ||
        (Order::UNALLOCATE_STATUSES.include?(order.status) && Order::SOLD_STATUSES.include?(params[:status]))
    end

    def change_status_to_cancel(order_summary)
      if params[:store_id].present?
        import_item = order_summary.import_items.find_by_store_id(params[:store_id])
        import_item = ImportItem.where(store_id: params[:store_id]).last if import_item.blank?
        import_item.update_attributes(status: 'cancelled') rescue nil
      else
        order_summary.import_items.update_all(status: 'cancelled')
        order_summary.update_attributes(status: 'completed')
      end
    end

    def delete_selected_orders(orders)
      orders.each do |order|
        set_status_and_message(false, order.errors.full_messages, ['&']) unless order.destroy
      end
    end
end