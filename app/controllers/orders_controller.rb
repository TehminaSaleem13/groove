# frozen_string_literal: true

class OrdersController < ApplicationController
  before_action :groovepacker_authorize!
  include OrderConcern
  include ActionView::Helpers::NumberHelper

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

    render body: nil
  end

  def update
    if current_user.can?('create_edit_notes')
      @order.notes_internal = begin
                                params[:order]['notes_internal']
                              rescue StandardError
                                nil
                              end
    else
      set_status_and_message(false, 'You do not have the permissions to edit notes', ['push'])
    end
    update_order_attrs

    @result['messages'].push(@order.errors.full_messages) if @result['status'] && @order.save

    if begin
          params[:app]
       rescue StandardError
         @params[:app]
        end
      orders_scanning_count = Order.multiple_orders_scanning_count(Order.where(id: @order.id))
      itemslength = begin
                      orders_scanning_count[@order.id].values.sum
                    rescue StandardError
                      0
                    end
      @result['scan_pack_data'] = generate_order_hash_v2(@order, itemslength)
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
    # GroovRealtime::emit('test',{does:'it work for user '+current_user.username+'?'})
    # GroovRealtime::emit('test',{does:'it work for tenant '+Apartment::Tenant.current+'?'},:tenant)
    # GroovRealtime::emit('test',{does:'it work for global?'},:global)
    @result['orders'] = make_orders_list(@orders)
    if params[:app]
      @result['general_settings'] = GeneralSetting.last.attributes.slice(*filter_general_settings).merge(GeneralSetting.last.per_tenant_settings)
      @result['scan_pack_settings'] = ScanPackSetting.last.attributes.slice(*filter_scan_pack_settings)
      @result['orders_count'] = get__filtered_orders_count
    else
      @result['orders_count'] = get_orders_count
    end
    render json: @result
  end

  def duplicate_orders
    execute_groove_bulk_action('duplicate')
    render json: @result
    # if current_user.can?('add_edit_order_items')
    #   GrooveBulkActions.execute_groove_bulk_action("duplicate", params, current_user, list_selected_orders)
    #   # @result = Order.duplicate_selected_orders(list_selected_orders, current_user, @result)
    # else
    #   set_status_and_message(false, "You do not have enough permissions to duplicate order", ['push'])
    # end
    # render json: @result
  end

  def print_activity_log
    result = { status: true }
    begin
      order = Order.find(params[:id])
      file = Tempfile.new("Order_Activity_Log#{order.id}.txt")
      begin
        order.order_activities.each do |activity|
          file.puts "Username: #{activity.username}"
          file.puts "Time: #{activity.activitytime}"
          file.puts "Activity: #{activity.action}"
          file.puts ''
        end
        file.close

        result[:logs] = IO.read(file.path)
      ensure
        file.delete
      end
    rescue StandardError => e
      result[:status] = false
      result[:error] = e
    end
    render plain: result[:logs]
  end

  def delete_orders
    execute_groove_bulk_action('delete')
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
    if params[:search].blank?
      set_status_and_message(false, 'Improper search string')
    else
      @orders = gp_orders_search.do_search(false)
      @result['orders'] = make_orders_list(@orders['orders'])
      @result['orders_count'] = get_orders_count
      @result['orders_count']['search'] = @orders['count']
    end
    render json: @result
  end

  def change_orders_status
    @user = User.find_by_confirmation_code(params[:confirmation_code])
    if current_user.can? 'change_order_status' or @user.can? 'change_order_status'
      GrooveBulkActions.execute_groove_bulk_action('status_update', params, current_user, list_selected_orders)
      # list_selected_orders.each { |order| change_order_status(order) }
    else
      set_status_and_message(false, 'You do not have enough permissions to change order status', %w[push error_messages])
    end
    render json: @result
  end

  def clear_assigned_tote
    execute_groove_bulk_action('clear_assigned_tote')
    render json: @result
  end

  def clear_order_tote
    @order.reset_assigned_tote(current_user.id)
    render json: { status: true }
  end

  def show
    if @order.nil?
      set_status_and_message(false, 'Could not find order' ['error_messages'])
    else
      @result['order'] = { 'basicinfo' => @order }
      retrieve_order_items
    end
    render json: @result
  end

  def create
    @result = Order.create_new_order(@result, current_user)
    render json: @result
  end

  def record_exception
    if params[:reason].blank?
      set_status_and_message(false, 'Cannot record exception without a reason', ['&', 'push'])
    else
      # Finiding @order in concern
      @result = gp_orders_exception.record_exception(@order, Apartment::Tenant.current)
    end
    render json: @result
  end

  def clear_exception
    # Finiding order in concern
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
    # setting status to false in concern if user is not permitted to 'add_edit_order_items' orders_items
    @result = gp_orders_module.add_item_to_order if @result['status']
    render json: @result
  end

  def update_item_in_order
    # setting status to false in concern if user is not permitted to 'add_edit_order_items' orders_items
    @result = gp_orders_module.update_order_item if @result['status']
    render json: @result
  end

  def remove_item_from_order
    # setting status to false in concern if user is not permitted to 'add_edit_order_items' orders_items
    @result = gp_orders_module.remove_item_from_order if @result['status']
    render json: @result
  end

  def rollback
    if params[:single].nil?
      set_status_and_message(false, 'Order can not be nil', ['&', 'push'])
    else
      rollback_order_changes
    end
    render json: @result
  end

  def save_by_passed_log
    # Finiding order in concern
    if @order.nil?
      set_status_and_message(false, 'Cannot find Order', ['error_msg'])
    else
      @result = gp_orders_module.add_by_passed_activity(@order, params[:sku])
    end
    render json: @result
  end

  def update_order_list
    # Finiding order in concern
    if @order.nil?
      set_status_and_message(false, 'Cannot find Order', ['error_msg'])
    else
      @result = gp_orders_module.update_orders_list(@order)
    end
    render json: @result
  end

  def generate_pick_list
    @result, @pick_list, @depends_pick_list =
      gp_orders_module.generate_pick_list(list_selected_orders)

    file_name = 'pick_list_' + Time.current.strftime('%d_%b_%Y_%H_%M_%S_%p')
    @result['data'] = { 'pick_list' => @pick_list, 'depends_pick_list' => @depends_pick_list, 'pick_list_file_paths' => "/pdfs/#{file_name}.pdf" }
    render_pdf(file_name)
    pdf_file = File.open(Rails.root.join('public', 'pdfs', "#{file_name}.pdf"), 'rb')
    base_file_name = File.basename(Rails.root.join('public', 'pdfs', "#{file_name}.pdf"))
    tenant_name = Apartment::Tenant.current
    GroovS3.create_pdf(tenant_name, base_file_name, pdf_file.read)
    pdf_file.close
    @result['url'] = ENV['S3_BASE_URL'] + '/' + tenant_name + '/pdf/' + base_file_name
    respond_to do |format|
      format.html {}
      format.pdf {}
      format.json do
        # render_pdf(file_name) #defined in application helper
        render json: @result
      end
    end
  end

  def generate_packing_slip
    @result['status'] = false
    settings_to_generate_packing_slip
    @orders = []
    list_selected_orders.each { |order| @orders.push(id: order.id, increment_id: order.increment_id) }

    unless @orders.empty?
      generate_barcode_for_packingslip
      @result['status'] = true
    end
    render json: @result
  end

  def generate_all_packing_slip
    @public_ip = `curl http://checkip.amazonaws.com` unless Rails.env.development?
    if params[:select_all].blank?
      @orders = params['filter'] == 'all' ? Order.all : Order.where(status: params['filter'])
      value = (params['sort'] == 'custom_field_one' || params['sort'] == 'custom_field_two' || params['sort'] == 'order_date' || params['sort'] == 'ordernum' || params['sort'] == 'status')
      @orders = value ? sort_order(params, @orders) : @orders
    else
      @orders = gp_orders_search.do_search(false)
      value = (params['sort'] == 'custom_field_one' || params['sort'] == 'custom_field_two' || params['sort'] == 'order_date' || params['sort'] == 'ordernum' || params['sort'] == 'status')
      @orders = value ? sort_order(params, @orders['orders']) : @orders['orders']
    end
    @orders.map(&:increment_id).each { |increment_id| generate_order_barcode_for_html(increment_id) }
  end

  def cancel_packing_slip
    if params[:id].nil?
      set_status_and_message(false, 'No id given. Can not cancel generating', %w[push error_messages])
    else
      barcode = GenerateBarcode.find_by_id(params[:id])
      cancel_packing(barcode)
    end
    render json: @result
  end

  # The method is called when Export Items link is clicked from Webclient.
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
      set_status_and_message(false, 'You do not have the permission to import orders', %w[push error_messages])
    end
    render json: @result
  end

  def import
    if order_summary.nil? && no_running_imports(params[:store_id]) # order_summary defined in application helper
      initiate_import_for_single_store
    else
      set_status_and_message(false, 'Import is in progress', %w[push error_messages])
    end
    render json: @result
  end

  def import_for_ss
    result = { error_messages: 'An Import is already in queue or running, please wait for it to complete!', status: false }
    params[:tenant] = Apartment::Tenant.current
    params[:current_user_id] = current_user.id
    if no_running_imports(params[:store_id])
      ImportOrders.new.delay(queue: "start_range_import_#{Apartment::Tenant.current}", priority: 95).import_range_import(params)
      result[:success_messages] = params[:import_type] == 'range_import' ? 'Range Import will start!' : 'Quickfix Import will start!'
      result[:status] = true
    end
    render json: result
  end

  def no_running_imports(store_id)
    ImportItem.where('status NOT IN (?) AND store_id = ?', %w[cancelled completed failed], store_id).blank?
  end

  def import_xml
    begin
      order_import_summary = OrderImportSummary.includes(:import_items).find(params[:import_summary_id])
      import_item = order_import_summary.import_items.where(store_id: params[:store_id])
      import_item = import_item.first
    rescue StandardError
      import_item = nil
    end

    if $redis.get("#{Apartment::Tenant.current}-#{OrderImportSummary.first.try(:id)}") != 'cancelled'
      if import_item && !import_item.eql?('cancelled')
        if params[:order_xml].nil?
          # params[:xml] has content
          file_name = Time.current.to_i.to_s + "#{SecureRandom.random_number(100)}.xml"
          File.open(Rails.root.join('public', 'csv', file_name), 'wb') do |file|
            file.write(params[:xml])
          end
        else
          order_xml = params[:order_xml]
          file_name = Time.current.to_i.to_s + "_#{SecureRandom.random_number(100)}" + order_xml.original_filename
          File.open(Rails.root.join('public', 'csv', file_name), 'wb') do |file|
            file.write(order_xml.read)
          end
        end

        order_importer = Groovepacker::Orders::Xml::Import.new(file_name, params['file_name'], params['flag'])
        order_importer.process

        if File.exist?(Rails.root.join('public', 'csv', file_name))
          File.delete(Rails.root.join('public', 'csv', file_name))
        end
      else
        import_item&.save
      end
    end
    render json: { status: 'OK' }
  end

  def cancel_import
    if order_summary_to_cancel.nil? # order_summary defined in application helper
      set_status_and_message(false, 'No imports are in progress', %w[push error_messages])
    else
      $redis.set("#{Apartment::Tenant.current}-#{OrderImportSummary.first.id}", 'cancelled')
      $redis.expire("#{Apartment::Tenant.current}-#{OrderImportSummary.first.id}", 20_000)
      change_status_to_cancel
      properties = {
        title: 'Order Import Canceled',
        tenant: Apartment::Tenant.current,
        user_id: current_user.id,
        username: current_user.username,
        store_id: params[:store_id]
      }
      ahoy.track('Order Import', properties, time: Time.current)
      Ahoy::Event.create(version_2: true, time: Time.current, properties: properties)
    end
    render json: @result
  end

  def cancel_all
    @result = {}
    import_items = ImportItem.where(status: %w[in_progress not_started]).update_all(status: 'cancelled', message: 'cancel_all')
    top_summary = OrderImportSummary.top_summary
    if top_summary
      top_summary.update_attributes(status: 'cancelled')
      top_summary.emit_data_to_user(true)
    end
    OrderImportSummary.destroy_all
    set_status_and_message(true, 'Status Updated')
    render json: @result
  end

  def get_id
    orders = Order.where(increment_id: params['increment_id'])
    @order_id = orders.first.id unless orders.empty?

    render json: @order_id
  end

  def run_orders_status_update
    Groovepacker::Orders::BulkActions.new.delay(priority: 95).update_bulk_orders_status(@result, params, Apartment::Tenant.current)
    render json: @result
  end

  def next_split_order
    original_id = params[:id]
    key = begin
            params[:id].split(' (S')[0..(params[:id].split(' (S').length - 2)].join + ' (S%'
          rescue StandardError
            nil
          end
    # key_array = params[:id].split("-")
    # if key_array.count == 1
    #   key = key_array.first
    # else
    #   last_value = Integer(key_array.last) rescue nil
    #   last_value = nil if key_array.last[0] == "0"
    #   if last_value.blank?
    #     key = key_array.join("-")
    #   elsif last_value.between?(1, 50)
    #     key_array.pop
    #     key = key_array.join('-') rescue key_array.first
    #   else
    #     key = key_array.join('-')
    #   end
    # end
    # order = Order.where("increment_id LIKE ? AND increment_id != ? AND status != ?", "#{key}%", original_id, "scanned").order("created_at asc").first
    order = Order.where('increment_id LIKE ? AND increment_id != ? AND status != ?', key, original_id, 'scanned').order('created_at asc').first
    render json: order
  end

  # def match
  #   @matching_orders = Order.where('postcode LIKE ?', "#{params['confirm']['postcode']}%")
  #   unless @matching_orders.nil?
  #     @matching_orders = @matching_orders.where(email: params['confirm']['email'])
  #   end
  #   render 'match'
  # end

  def create_ss_label
    render json: Order.new.create_label(params[:credential_id], params[:post_data].permit!.to_h)
  end

  def get_realtime_rates
    result = { status: true }

    begin
      ss_label_data = {}
      ss_credential = ShipstationRestCredential.find(params[:credential_id])
      ss_client = Groovepacker::ShipstationRuby::Rest::Client.new(ss_credential.api_key, ss_credential.api_secret)
      ss_label_data['available_carriers'] = begin
                                              JSON.parse(ss_client.list_carriers.body)
                                            rescue StandardError
                                              []
                                            end
      requested_carriers = params[:carrier_code].to_s.split(',').map(&:strip)
      if requested_carriers.any?
        ss_label_data['available_carriers'] = ss_label_data['available_carriers'].select { |carrier| requested_carriers.include? carrier['code'] }
      end
      ss_label_data['available_carriers'].each do |carrier|
        carrier['visible'] = !(ss_credential.disabled_carriers.include? carrier['code'])
        carrier['expanded'] = !(ss_credential.contracted_carriers.include? carrier['code'])
        next if params[:app] && !carrier['expanded']
        next unless carrier['visible']

        data = {
          carrierCode: carrier['code'],
          weight: params[:post_data][:weight].try(:permit!).try(:to_h),
          fromPostalCode: params[:post_data][:fromPostalCode],
          toCountry: params[:post_data][:toCountry],
          toState: params[:post_data][:toState],
          toPostalCode: params[:post_data][:toPostalCode],
          confirmation: params[:post_data][:confirmation]
        }
        rates_response = ss_client.get_ss_label_rates(data.to_h)
        carrier['errors'] = rates_response.first(3).map { |res| res = res.join(': ') }.join('<br>') unless rates_response.ok?
        next unless rates_response.ok?

        carrier['rates'] = JSON.parse(rates_response.body)
        carrier['services'] = JSON.parse(ss_client.list_services(carrier['code']).body) if carrier['code'] == 'stamps_com'
        carrier['packages'] = JSON.parse(ss_client.list_packages(carrier['code']).body) if carrier['code'] == 'stamps_com'
        carrier['rates'].map { |r| r['carrierCode'] = carrier['code'] }
        carrier['rates'].map { |r| r['cost'] = number_with_precision((r['shipmentCost'] + r['otherCost']), precision: 2) }
        carrier['rates'].map do |r|
          r['visible'] = !(begin
                            (ss_credential.disabled_rates[carrier['code']].include? r['serviceName'])
                          rescue StandardError
                            false
                          end)
        end
        carrier['rates'].sort_by! { |hsh| hsh['cost'].to_f }
        next unless carrier['code'] == 'stamps_com'

        carrier['rates'].each do |rate|
          rate['packageCode'] = begin
                                  carrier['packages'].select { |h| h['name'] == rate['serviceName'].split(' - ').last }.first['code']
                                rescue StandardError
                                  nil
                                end
        end
      end
      result[:ss_label_data] = ss_label_data
    rescue StandardError => e
      result[:status] = false
      result[:error_messages] = e.message
    end

    render json: result
  end

  def update_ss_label_order_data
    result = { status: true }

    begin
      order = Order.find_by(increment_id: params[:order_number])

      name = params[:ss_label_data][:shipping_address][:name].split(' ')
      if name.present?
        order.firstname = name.first
        order.lastname = name[1..name.length].join(' ')
      else
        order.firstname = ''
        order.lastname = ''
      end
      order.address_1 = params[:ss_label_data][:shipping_address][:address1] || ''
      order.address_2 = params[:ss_label_data][:shipping_address][:address2] || ''
      order.state = params[:ss_label_data][:shipping_address][:state] || ''
      order.city = params[:ss_label_data][:shipping_address][:city] || ''
      order.postcode = params[:ss_label_data][:shipping_address][:postal_code] || ''
      order.country = params[:ss_label_data][:shipping_address][:country] || ''
      order.ss_label_data = (order.ss_label_data || {}).merge(weight: params[:ss_label_data][:weight].to_unsafe_h, dimensions: params[:ss_label_data][:dimensions].to_unsafe_h)
      order.save
    rescue StandardError
      result = { status: false }
    end

    render json: result
  end

  def print_shipping_label
    result = { status: true }
    begin
      order = Order.includes(:store).find(params[:id])
      if order.store.store_type == 'Shipstation API 2' && order.store.shipstation_rest_credential.try(:use_api_create_label)
        result = order.try_creating_label
        result[:ss_label_order_data] = order.ss_label_order_data(skip_trying: true, params: params)
        result[:error] = 'Insufficient data to create label' if !result[:status] && !result[:error_messages].present?
      else
        result[:status] = false
        result[:error] = 'Please Check Order Store Settings'
      end
    rescue StandardError => e
      result[:status] = false
      result[:error] = e
    end
    render json: result
  end

  def remove_packing_cam_image
    result = { status: true }
    begin
      packing_cam = PackingCam.joins(:order).where(orders: { id: params[:id] }).find(params[:packing_cam_id])
      result[:status] = GroovS3.delete_object(packing_cam.url.gsub("#{ENV['S3_BASE_URL']}/", ''))
      result[:error] = 'No Such Key' unless result[:status]
      packing_cam.destroy
    rescue StandardError => e
      result[:status] = false
      result[:error] = e
    end
    render json: result
  end

  def send_packing_cam_email
    order = Order.find(params[:id])
    packing_cam = order.packing_cams.last || order.packing_cams.build
    packing_cam.notify_user

    render json: { status: true }
  end

  def get_ss_label_data
    result = { status: true }
    begin
      order = Order.includes(:store).find(params[:id])
      if order.store.store_type == 'Shipstation API 2' && order.store.shipstation_rest_credential.try(:use_api_create_label)
        result[:ss_label_order_data] = order.ss_label_order_data(skip_trying: true, params: params)
      else
        result[:status] = false
      end
    rescue StandardError => e
      result[:status] = false
      result[:error] = e
    end
    render json: result
  end

  private

  def execute_groove_bulk_action(activity)
    params[:user_id] = current_user.id
    if current_user.can?('add_edit_order_items')
      GrooveBulkActions.execute_groove_bulk_action(activity, params, current_user, list_selected_orders)
    else
      set_status_and_message(false, "You do not have enough permissions to #{activity}", %w[push error_messages])
    end
  end
end
