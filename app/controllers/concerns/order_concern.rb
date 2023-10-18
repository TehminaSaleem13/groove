# frozen_string_literal: true

module OrderConcern
  extend ActiveSupport::Concern

  included do
    before_action :groovepacker_authorize!, except: %i[import_shipworks generate_all_packing_slip]
    prepend_before_action :initialize_result_obj, only: %i[index importorders clear_exception record_exception import_all order_items_export update_order_list cancel_packing_slip duplicate_orders delete_orders change_orders_status generate_pick_list update show update_item_in_order rollback remove_item_from_order add_item_to_order search import cancel_import generate_packing_slip run_orders_status_update create generate_all_packing_slip]
    before_action :find_order, only: %i[update show record_exception clear_exception update_order_list save_by_passed_log clear_order_tote]
    before_action :check_order_edit_permissions, only: %i[add_item_to_order update_item_in_order remove_item_from_order]
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
    ids = result_rows.map { |p| p['id'] }
    orders = Order.where('id IN (?)', ids)
    orders = params[:sort] == 'custom_field_one' || params[:sort] == 'custom_field_two' || params['sort'] == 'order_date' || params['sort'] == 'ordernum' || params['sort'] == 'status' ? sort_order(params, orders) : orders
  end

  def get_orders_list_for_selected(sort_by_order_number = false)
    @params = params
    result =  if @params[:select_all] || @params[:inverted]
                list_of_all_selected_or_inverted(sort_by_order_number)
              elsif @params[:orderArray].present?
                list_of_orders_from_orderArray(sort_by_order_number)
              elsif @params[:id].present?
                Order.where(id: @params[:id])
              else
                list_of_orders_by_sort_order(sort_by_order_number)
              end
  end

  def list_of_all_selected_or_inverted(sort_by_order_number = false)
    @params = @params.merge(sort: 'ordernum', order: 'ASC') if sort_by_order_number
    result = @params[:search].blank? ? gp_orders_module.do_getorders : gp_orders_search.do_search
  end

  def list_of_orders_from_orderArray(sort_by_order_number = false)
    result = @params[:orderArray]
    result = Order.where(id: @params[:orderArray].map(&:values).flatten).order(:increment_id) if sort_by_order_number
    result
  end

  def list_of_orders_by_sort_order(sort_by_order_number = false)
    result = Order.where(id: @params[:order_ids])
    result = result.order(:increment_id) if sort_by_order_number
    result
  end

  def create_results_row(result)
    return result unless params[:inverted] && params[:orderArray].present?

    not_in = []
    result_rows = []

    params[:orderArray].each { |order| not_in.push(order['id']) }

    result.each do |single_order|
      result_rows.push(single_order) unless not_in.include? single_order['id']
    end
    result_rows
  end

  def get_orders_count
    count = {}
    all = 0
    counts = Order.select('status,count(*) as count').where(status: %w[scanned cancelled onhold awaiting serviceissue]).group(:status)
    counts.each do |single|
      count[single.status] = single.count
      all += single.count
    end
    count = count.merge('all' => all, partially_scanned: Order.partially_scanned.count, 'search' => 0)
  end

  def get__filtered_orders_count
    count = {}
    all = 0
    counts = Order.select('status,count(*) as count').where(status: %w[scanned awaiting]).group(:status)
    counts.each do |single|
      count[single.status] = single.count
      all += single.count
    end
    count = count.merge('all' => all, partially_scanned: Order.partially_scanned.count, 'search' => 0)
  end

  def cancel_packing(barcode)
    if barcode.nil?
      @result['error_messages'].push('No barcode found with the id.')
      return
    end
    barcode.cancel = true
    unless barcode.status == 'in_progress'
      barcode.status = 'cancelled'
      begin
        the_delayed_job = Delayed::Job.find(barcode.delayed_job_id)
        the_delayed_job&.destroy
      rescue Exception => e
      end
    end

    if barcode.save
      @result['notice_messages'].push('Pdf generation marked for cancellation. Please wait for acknowledgement.')
    end
  end

  def import_result_messages(import_result)
    import_result[:messages].each { |msg| @result['messages'].push(msg) }

    @result.merge('status' => !!import_result[:status],
                  'total_imported' => import_result[:total_imported],
                  'success_imported' => import_result[:success_imported],
                  'previous_imported' => import_result[:previous_imported])
  end

  def update_order_attrs
    status = @order.status
    return if status == 'scanned'

    check_inactive_or_new_products
    update_order_notes # Everyone can create notes from Packer

    if current_user.can?('add_edit_order_items')
      update_attrs_from_params
    elsif check_update_permissions
      set_status_and_message(false, 'You do not have enough permissions to edit the order', ['push'])
    end
  end

  def check_inactive_or_new_products
    if !@order.has_inactive_or_new_products
      @order.status = 'awaiting'
    elsif @order.status.eql? 'awaiting'
      @order.status = 'onhold'
    end
  end

  def update_order_notes
    @order.notes_fromPacker = params[:order]['notes_fromPacker']

    if current_user.can?('create_edit_notes')
      @order.notes_internal = params[:order]['notes_internal']
      @order.notes_toPacker = params[:order]['notes_toPacker']
    elsif check_update_permissions(%w[notes_internal notes_toPacker])
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
    flag
  end

  def update_attrs_from_params
    attr_array = %w[address_2 shipping_amount order_total weight_oz]
    order_update_attrs.each do |attr|
      if attr_array.include?(attr)
        @order[attr] = params[:order][attr] unless params[:order][attr].nil?
      else
        @order[attr] = params[:order][attr]
      end
    end
  end

  def order_update_attrs
    %w[firstname lastname company address_1 address_2 city state postcode country email increment_id order_placed_time customer_comments tags scanned_on tracking_num seller_id order_status_id order_number ship_name notes_from_buyer shipping_amount order_total weight_oz note_confirmation custom_field_one custom_field_two status]
  end

  def retrieve_order_items
    # Retrieve order items
    @result['order']['items'] = []
    @order.order_items.includes(
      product: %i[
        product_inventory_warehousess
        product_skus product_cats product_barcodes
        product_images
      ]
    ).each do |orderitem|
      @result['order']['items'].push(retrieve_order_item(orderitem))
    end
    @result['order']['storeinfo'] = @order.store

    set_user_permissions # setting user permissions for add and remove items permitted
    set_unacknowledged_activities # Retrieve Unacknowledged activities
    add_a_nobody_user # Add nobody user info if user info not available

    @result['order']['tags'] = @order.order_tags
    box_data = @order.get_boxes_data
    @result['order']['boxes'] = box_data[:box]
    @result['order']['order_item_boxes'] = box_data[:order_item_boxes]
    @result['order']['order_item_in_boxes'] = box_data[:order_item_in_boxes]
    @result['order']['list'] = box_data[:list]
    @result['order']['packing_cams'] = @order.packing_cams
    @result['order'] = @order.get_se_old_shipments(@result['order'])
    # @result['order']['se_duplicate_orders'] = se_duplicate_orders(@order)
    # @result['order']['se_old_shipments'] = se_old_shipments(@order) if @result['order']['se_duplicate_orders'].blank?
    # @result['order']['se_all_shipments'] = se_all_shipments(@order) if @result['order']['se_old_shipments'].blank?
  end

  def retrieve_order_item(orderitem)
    orderitem_attributes = orderitem.attributes
    orderitem_attributes['qty'] = orderitem.qty + orderitem.skipped_qty
    order_item = { 'iteminfo' => orderitem_attributes }
    product = orderitem.product
    if product.nil?
      order_item['productinfo'] = nil
      order_item['productimages'] = nil
    else
      product_available_inv = order_item_available_inv(product)
      product_attrs = init_product_attrs(product, product_available_inv)
      order_item = order_item.merge(product_attrs)
    end
    order_item
  end

  def set_user_permissions
    # TODO: Limiting Order activities to 1500 as on now. (newageincense Issue) https://groovepacker.slack.com/archives/C07BB0MEW/p1664449414094749
    @result['order'] = @result['order'].merge('add_items_permitted' => current_user.can?('add_edit_order_items'),
                                              'remove_items_permitted' => current_user.can?('add_edit_order_items'),
                                              'activities' => @order.order_activities.limit(1500))
  end

  def set_unacknowledged_activities
    @result['order']['unacknowledged_activities'] = @order.unacknowledged_activities
    @result['order']['exception'] = @order.order_exception if current_user.can?('view_packing_ex')
    if current_user.can?('view_packing_ex') && !@order.order_exception.nil? && !@order.order_exception.user_id.in?([0, nil])
      @result['order']['exception'] = @result['order']['exception'].attributes.merge('assoc' => User.where(id: @order.order_exception.user_id).first)
    end
  end

  def order_item_available_inv(product)
    available_inv = 0
    inv_warehouses = product.product_inventory_warehousess
    inv_warehouses.each { |iwh| available_inv += iwh.available_inv.to_i }
    available_inv
  end

  def rollback_order_changes
    order = Order.find_by_id(params[:single]['basicinfo']['id'])
    if order.nil?
      set_status_and_message(false, 'Wrong order id', ['&', 'push'])
      return
    end
    @result = gp_orders_exception.add_edit_order_items(order)
    @result = gp_orders_exception.edit_packing_execptions(order, Apartment::Tenant.current)
  end

  def generate_barcode_for_packingslip
    GenerateBarcode.where('updated_at < ?', 24.hours.ago).delete_all
    generate_barcode = GenerateBarcode.generate_barcode_for(@orders, current_user)
    delayed_job = GeneratePackingSlipPdf.delay(run_at: 1.seconds.from_now, queue: 'generate_packing_slip', priority: 95).generate_packing_slip_pdf(@orders, current_tenant, @result, @page_height, @page_width, @orientation, @file_name, @size, @header, generate_barcode.id, @boxes, @is_custom_pdf)
    generate_barcode.delayed_job_id = delayed_job.id
    generate_barcode.save
  end

  def add_a_nobody_user
    # add a user with name of nobody to display in the list
    dummy_user = User.new
    dummy_user.name = 'Nobody'
    dummy_user.username = 'Nobody'
    dummy_user.id = 0
    @result['order']['users'] = User.all.to_a
    @result['order']['users'].unshift(dummy_user)

    user = @result['order']['users'].select { |user| user.id == @order.packing_user_id }.first
    user.name = "#{user.name} (Packing User)" if user
  end

  def find_order
    @orders_result = []
    @order = Order.find_by_id(params[:id])
    return if @order.blank?
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
    return if current_user.can? 'add_edit_order_items' or params[:is_allowed]

    set_status_and_message(false, 'You can not add or edit order items', ['&', 'push'])
  end

  def initiate_import_for_single_store
    store = Store.find_by_id(params[:store_id])
    Delayed::Job.where(queue: 'importing_orders_' + current_tenant).destroy_all
    import_params = { tenant: current_tenant, store: store, import_type: params[:import_type], user: current_user, days: params[:days] }
    ImportOrders.new.import_order_by_store(import_params)
  end

  def change_status_to_cancel
    if params[:store_id].present?
      import_item = order_summary_to_cancel.import_items.find_by_store_id(params[:store_id])
      import_item = ImportItem.where(store_id: params[:store_id]).last if import_item.blank?
      begin
        import_item.status = 'cancelled'
        import_item.save
        total_summary = OrderImportSummary.all
        total_summary.each do |import_summary|
          import_summary.status = 'cancelled'
          import_summary.save
        end
      rescue StandardError
        nil
      end
    else
      ImportItem.update_all(status: 'cancelled')
      items = ImportItem.joins(:store).where("stores.store_type='CSV' and (import_items.status='in_progress' OR import_items.status='not_started' OR import_items.status='failed')")
      begin
        items.each { |item| item.update_attributes(status: 'cancelled') }
      rescue StandardError
        nil
      end
      order_import_summary = OrderImportSummary.all
      order_import_summary.each do |import_summary|
        import_summary.status = 'cancelled'
        import_summary.save
      end
    end
    ElixirApi::Processor::CSV::OrdersToXML.delay(run_at: 1.seconds.from_now, queue: "cancel_import_#{Apartment::Tenant.current}", priority: 95).cancel_import(request.subdomain)
  end

  def filter_scan_pack_settings
    ScanPackSetting.column_names
  end

  def filter_general_settings
    GeneralSetting.column_names
   end

  # def delete_selected_orders(orders)
  #   orders.each do |order|
  #     set_status_and_message(false, order.errors.full_messages, ['&']) unless order.destroy
  #   end
  # end
end
