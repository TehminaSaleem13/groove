class OrdersController < ApplicationController
  before_filter :groovepacker_authorize!
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
    execute_groove_bulk_action("duplicate")
    render json: @result
    # if current_user.can?('add_edit_order_items')
    #   GrooveBulkActions.execute_groove_bulk_action("duplicate", params, current_user, list_selected_orders)
    #   # @result = Order.duplicate_selected_orders(list_selected_orders, current_user, @result)
    # else
    #   set_status_and_message(false, "You do not have enough permissions to duplicate order", ['push'])
    # end
    # render json: @result
  end

  def delete_orders
    execute_groove_bulk_action("delete")
    render json: @result
    # if current_user.can? 'add_edit_order_items'
    #   GrooveBulkActions.execute_groove_bulk_action("delete", params, current_user, list_selected_orders)
    #   # delete_selected_orders(list_selected_orders)
    # else
    #   set_status_and_message(false, "You do not have enough permissions to delete order", ['push'])
    # end
    # render json: @result
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
      GrooveBulkActions.execute_groove_bulk_action("status_update", params, current_user, list_selected_orders)
      # list_selected_orders.each { |order| change_order_status(order) }
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
      @result = gp_orders_exception.record_exception(@order, Apartment::Tenant.current)
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
      @result = @order.destroy_exceptions(@result, current_user, Apartment::Tenant.current)
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

    file_name = 'pick_list_'+Time.now.strftime('%d_%b_%Y_%H_%M_%S_%p')
    @result['data'] = { 'pick_list' => @pick_list, 'depends_pick_list' => @depends_pick_list, 'pick_list_file_paths' => "/pdfs/#{file_name}.pdf"}
    render_pdf(file_name)
    pdf_file = File.open(Rails.root.join('public', 'pdfs', "#{file_name}.pdf"), 'rb')
    base_file_name = File.basename(Rails.root.join('public', 'pdfs', "#{file_name}.pdf"))
    tenant_name = Apartment::Tenant.current
    GroovS3.create_pdf(tenant_name, base_file_name, pdf_file.read)
    pdf_file.close
    @result["url"] = ENV['S3_BASE_URL']+'/'+tenant_name+'/pdf/'+base_file_name
    respond_to do |format|
      format.html {}
      format.pdf {}
      format.json {
        # render_pdf(file_name) #defined in application helper
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

  def generate_all_packing_slip
    @orders = params["filter"] == "all" ? Order.all : Order.where(status: params["filter"])
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

  #The method is called when Export Items link is clicked from Webclient.
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

  def import_xml
    order_import_summary = OrderImportSummary.find(params[:import_summary_id])
    import_item = order_import_summary.import_items.where(store_id: params[:store_id])
    import_item = import_item.first
    if import_item && !import_item.eql?('cancelled')
      if params[:order_xml].nil?
        # params[:xml] has content
        file_name = Time.now.to_i.to_s + ".xml"
        File.open(Rails.root.join('public', 'csv', file_name), 'wb') do |file|
          file.write(params[:xml])
        end
      else
        order_xml = params[:order_xml]
        file_name = Time.now.to_i.to_s + "_" + order_xml.original_filename
        File.open(Rails.root.join('public', 'csv', file_name), 'wb') do |file|
          file.write(order_xml.read)
        end
      end
      order_importer = Groovepacker::Orders::Xml::Import.new(file_name)
      order_importer.process
      File.delete(Rails.root.join('public', 'csv', file_name))
    else
      import_item && import_item.save
    end

    render json: {status: "OK"}
  end

  def cancel_import
    if order_summary_to_cancel.nil?   #order_summary defined in application helper
      set_status_and_message(false, "No imports are in progress", ['push', 'error_messages'])
    else
      change_status_to_cancel
      ahoy.track(
        "Order Import",
        {
          title: "Order Import Canceled",
          tenant: Apartment::Tenant.current,
          user_id: current_user.id,
          store_id: params[:store_id]
        },
        time: Time.now,
      )
    end
    render json: @result
  end

  def get_id
    orders = Order.where(increment_id: params['increment_id'])
    @order_id = orders.first.id unless orders.empty?

    render json: @order_id
  end

  def run_orders_status_update
    Groovepacker::Orders::BulkActions.new.delay.update_bulk_orders_status(@result, params, Apartment::Tenant.current)
    render json: @result
  end

  # def match
  #   @matching_orders = Order.where('postcode LIKE ?', "#{params['confirm']['postcode']}%")
  #   unless @matching_orders.nil?
  #     @matching_orders = @matching_orders.where(email: params['confirm']['email'])
  #   end
  #   render 'match'
  # end

  private
  def execute_groove_bulk_action(activity)
    params[:user_id] = current_user.id
    if current_user.can?('add_edit_order_items')
      GrooveBulkActions.execute_groove_bulk_action(activity, params, current_user, list_selected_orders)
    else
      set_status_and_message(false, "You do not have enough permissions to #{activity}", ['push', 'error_messages'])  
    end
  end
end
