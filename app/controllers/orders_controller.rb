class OrdersController < ApplicationController
  include OrderConcern
  
  # Import orders from store based on store id
  def importorders
    if check_user_permissions('import_orders')
      @result, @import_result = gp_orders_import.execute_import
      import_result_messages(@import_result) unless @import_result.blank?
    end
    render json: @result
  end

  def import_shipworks
    status = gp_orders_import.import_shipworks(params[:auth_token], request)
    
    render status: status, nothing: true
  end

  def update
    if current_user.can?('create_edit_notes')
      @order.notes_internal = params[:order]['notes_internal']
    else
      set_status_and_message(false, 'You do not have the permissions to edit notes', ['push'])
    end
    update_order_attrs
    
    if @result['status'] && @order.save
      @result['messages'].push(@order.errors.full_messages)
    end
    render json: @result
  end

  # Get list of orders based on limit and offset. It is by default sorted by updated_at field
  # If sort parameter is passed in then the corresponding sort filter will be used to sort the list
  # The expected parameters in params[:sort] are
  # . The API supports to provide order of sorting namely ascending or descending. The parameter can be
  # passed in using params[:order] = 'ASC' or params[:order] ='DESC' [Note: Caps letters] By default, if no order is mentioned,
  # then the API considers order to be descending.The API also supports a product status filter.
  # The filter expects one of the following parameters in params[:filter] 'all', 'active', 'inactive', 'new'.
  # If no filter is passed, then the API will default to 'active'
  def index
    @orders = gp_orders_module.do_getorders
    #GroovRealtime::emit('test',{does:'it work for user '+current_user.username+'?'})
    #GroovRealtime::emit('test',{does:'it work for tenant '+Apartment::Tenant.current+'?'},:tenant)
    #GroovRealtime::emit('test',{does:'it work for global?'},:global)
    @result['orders'] = make_orders_list(@orders)
    @result['orders_count'] = get_orders_count()
    render json: @result
  end

  def duplicate_orders
    if current_user.can?('add_edit_order_items')
      @result = Order.duplicate_selected_orders(list_selected_orders, current_user, @result)
    else
      set_status_and_message(false, "You do not have enough permissions to duplicate order", ['push'])
    end
    render json: @result
  end

  def delete_orders
    if current_user.can? 'add_edit_order_items'
      delete_selected_orders(list_selected_orders)
    else
      set_status_and_message(false, "You do not have enough permissions to delete order", ['push'])
    end
    render json: @result
  end

  # For search pass in parameter params[:search] and a params[:limit] and params[:offset].
  # If limit and offset are not passed, then it will be default to 10 and 0
  def search
    unless params[:search].blank?
      @orders = gp_orders_search.do_search(false)
      @result['orders'] = make_orders_list(@orders['orders'])
      @result['orders_count'] = get_orders_count()
      @result['orders_count']['search'] = @orders['count']
    else
      set_status_and_message(false, 'Improper search string')
    end
    render json: @result
  end

  def change_orders_status
    if current_user.can? 'change_order_status'
      list_selected_orders.each { |order| change_order_status(order) }
    else
      set_status_and_message(false, "You do not have enough permissions to change order status", ['push', 'error_messages'])
    end
    render json: @result
  end

  def show
    unless @order.nil?
      @result['order'] = {'basicinfo' => @order}
      retrieve_order_items
    else
      set_status_and_message(false, "Could not find order" ['error_messages'])
    end
    render json: @result
  end


  def record_exception
    unless params[:reason].blank?
      #Finiding @order in concern
      @result = gp_orders_exception.record_exception(@order)
    else
      set_status_and_message(false, 'Cannot record exception without a reason', ['&', 'push'])
    end
    render json: @result
  end

  def clear_exception
    #Finiding order in concern
    if @order.order_exception.nil?
      set_status_and_message(false, 'Order does not have exception to clear', ['&', 'push'])
    elsif current_user.can? 'edit_packing_ex'
      @result = @order.destroy_exceptions(@result, current_user)
    else
      set_status_and_message(false, 'You can not edit exceptions', ['&', 'push'])
    end
    render json: @result
  end

  def add_item_to_order
    #setting status to false in concern if user is not permitted to 'add_edit_order_items' orders_items
    @result = gp_orders_module.add_item_to_order if @result['status']
    render json: @result
  end

  def update_item_in_order
    #setting status to false in concern if user is not permitted to 'add_edit_order_items' orders_items
    @result = gp_orders_module.update_order_item if @result['status']
    render json: @result
  end

  def remove_item_from_order
    #setting status to false in concern if user is not permitted to 'add_edit_order_items' orders_items
    @result = gp_orders_module.remove_item_from_order if @result['status']
    render json: @result
  end

  def rollback
    if params[:single].nil?
      set_status_and_message(false, "Order can not be nil", ['&', 'push'])
    else
      rollback_order_changes
    end
    render json: @result
  end

  def update_order_list
    #Finiding order in concern
    if @order.nil?
      set_status_and_message(false, "Cannot find Order", ['error_msg'])
    else
      @result = gp_orders_module.update_orders_list(@order)
    end
    render json: @result
  end

  def generate_pick_list
    @result, @pick_list, @depends_pick_list  = 
                            gp_orders_module.generate_pick_list( list_selected_orders )

    file_name = 'pick_list_'+Time.now.strftime('%d_%b_%Y')
    @result['data'] = { 'pick_list' => @pick_list, 'depends_pick_list' => @depends_pick_list, 'pick_list_file_paths' => "/pdfs/#{file_name}.pdf"}

    respond_to do |format|
      format.html {}
      format.pdf {}
      format.json {
        render_pdf(file_name) #defined in application helper
        render json: @result
      }
    end
  end

  def generate_packing_slip
    @result['status'] = false
    settings_to_generate_packing_slip
    @orders = []
    list_selected_orders.each { |order| @orders.push({id: order.id, increment_id: order.increment_id}) }
    
    unless @orders.empty?
      generate_barcode_for_packingslip
      @result['status'] = true
    end
    render json: @result
  end

  def cancel_packing_slip
    if params[:id].nil?
      set_status_and_message(false, 'No id given. Can not cancel generating', ['push', 'error_messages'])
    else
      barcode = GenerateBarcode.find_by_id(params[:id])
      cancel_packing(barcode)
    end
    render json: @result
  end

  def order_items_export
    @result['filename'] = ''
    selected_orders = list_selected_orders(true)
    if selected_orders.nil?
      set_status_and_message(false, 'No orders selected', ['push'])
    else
      @result = gp_orders_export.order_items_export(selected_orders)
    end
    render json: @result
  end

  def import_all
    # import_orders_helper()
    if current_user.can? 'import_orders'
      @result = gp_orders_import.start_import_for_all
    else
      set_status_and_message(false, 'You do not have the permission to import orders', ['push', 'error_messages'])
    end
    render json: @result
  end

  def import
    if order_summary.nil?   #order_summary defined in application helper
      initiate_import_for_single_store
    else
      set_status_and_message(false, "Import is in progress", ['push', 'error_messages'])
    end
    render json: @result
  end

  def cancel_import
    if order_summary.nil?   #order_summary defined in application helper
      set_status_and_message(false, "No imports are in progress", ['push', 'error_messages'])
    else
      change_status_to_cancel(order_summary)
    end
    render json: @result
  end

  # def match
  #   @matching_orders = Order.where('postcode LIKE ?', "#{params['confirm']['postcode']}%")
  #   unless @matching_orders.nil?
  #     @matching_orders = @matching_orders.where(email: params['confirm']['email'])
  #   end
  #   render 'match'
  # end

end

