class ScanPackController < ApplicationController
  before_action :groovepacker_authorize!, :set_result_instance
  include ScanPackHelper

  def scan_pack_bug_report
    BugReportMailer.delay(priority: 95).report_bug(params, current_user.try(:username), Apartment::Tenant.current)
    render json: { status: 'OK' }
  end

  def scan_barcode
    scan_barcode_obj = ScanPack::ScanBarcodeService.new(
      current_user, session, params
    )
    render json: scan_barcode_obj.run.merge('awaiting' => get_awaiting_orders_count)
  end

  def scan_pack_v2
    if params[:data].present?
      tenant = Tenant.find_by_name(Apartment::Tenant.current)
      log_scn_obj = Groovepacker::ScanPackV2::LogScanService.new
      if tenant.expo_logs_delay
        session = session.present? ? session : nil
        log_scn_obj.delay(run_at: 1.seconds.from_now, priority: 95).process_logs(tenant.name, current_user.try(:id), session, params)
      else
        log_scn_obj.process_logs(tenant.name, current_user.try(:id), session, params)
      end
      # params[:data].each do |scn_params|
      #   begin
      #     if (scn_params[:event] == 'regular')
      #       scan_barcode_obj = ScanPack::ScanBarcodeService.new(
      #         current_user, session, scn_params
      #       )
      #       res = scan_barcode_obj.run
      #     elsif (scn_params[:event] == 'click_scan')
      #       res = product_scan(
      #         scn_params[:input], 'scanpack.rfp.default', scn_params[:id], scn_params[:box_id],
      #         {
      #           clicked: true, current_user: current_user, session: session
      #         }
      #       )
      #     elsif (scn_params[:event] == 'type_scan')
      #       res = product_scan(
      #         scn_params[:input], 'scanpack.rfp.default', scn_params[:id], scn_params[:box_id],
      #         {
      #           clicked: false, serial_added: false, typein_count: scn_params[:count].to_i,
      #           current_user: current_user, session: session
      #         }
      #       )
      #     elsif (scn_params[:event] == 'scanned')
      #       order = Order.find(scn_params[:id])
      #       if !order.nil?
      #         order.order_items.update_all(scanned_status: 'scanned')
      #         order.addactivity('Order is scanned through SCANNED barcode', current_user.try(:username))
      #         order.set_order_to_scanned_state(current_user.try(:username))
      #       end
      #     elsif (scn_params[:event] == 'note')
      #       ScanPack::AddNoteService.new(
      #         current_user, session, { id: scn_params[:id], note: scn_params[:message], email: true }
      #       ).run
      #     elsif (scn_params[:event] == 'verify')
      #       if scn_params[:state] == 'scanpack.rfp.no_tracking_info'
      #         render_order_scan_object = ScanPack::RenderOrderScanService.new(
      #           [current_user, scn_params[:input], 'scanpack.rfp.no_tracking_info', scn_params[:id]]
      #         )
      #         render_order_scan_object.run
      #       elsif scn_params[:state] == 'scanpack.rfp.no_match'
      #         render_order_scan_object = ScanPack::ScanAginOrRenderOrderScanService.new(
      #           [current_user, scn_params[:input], 'scanpack.rfp.no_match', scn_params[:id]]
      #         )
      #         render_order_scan_object.run
      #       else
      #         scan_verifying_object = ScanPack::ScanVerifyingService.new(
      #           [current_user, scn_params[:input], scn_params[:id]]
      #         )
      #       end
      #       scan_verifying_object.run
      #     elsif (scn_params[:event] == 'record')
      #       scan_recording_object = ScanPack::ScanRecordingService.new(
      #         [current_user, scn_params[:input], scn_params[:id]]
      #       )
      #       scan_recording_object.run
      #     elsif (scn_params[:event] == 'serial_scan')
      #       serial_scan_obj = ScanPack::SerialScanService.new(
      #         current_user, session, scn_params
      #       )
      #       serial_scan_obj.run
      #     elsif (scn_params[:event] == 'bulk_scan')
      #       order_item = OrderItem.find_by(id: scn_params[:order_item_id])
      #       if order_item && order_item.scanned_status != 'scanned'
      #         order = order_item.order
      #         order_item.update_attributes(scanned_status: 'scanned')
      #         order.addactivity("#{order_item.product.name} scanned through Bulk Scan", current_user.try(:username))
      #         order.set_order_to_scanned_state(current_user.try(:username)) unless order.has_unscanned_items
      #       end
      #     end
      #   rescue => e
      #     on_demand_logger = Logger.new("#{Rails.root}/log/scan_pack_v2.log")
      #     log = { tenant: Apartment::Tenant.current, params: params, scn_params: scn_params, error: e, time: Time.now.utc, backtrace: e.backtrace.join(",") }
      #     on_demand_logger.info(log)
      #   end
      # end
    end

    # Regular Scan
    # => <ActionController::Parameters {"_json"=>{{"input"=>"g", "id"=>203801, "time"=>"2020-07-31T13:50:17.140Z", "state"=>"scanpack.rfp.default", "event"=>"regular"}], "controller"=>"scan_pack", "action"=>"scan_pack_v2", "scan_pack"=>{"_json"=>[{"input"=>"g", "id"=>203801, "time"=>"2020-07-31T13:50:17.140Z", "state"=>"scanpack.rfp.default", "event"=>"regular"}]}} permitted: false>

    #Click Scan
    # => <ActionController::Parameters {"_json"=>[{"input"=>"g", "id"=>203801, "time"=>"2020-07-31T13:51:52.955Z", "state"=>"scanpack.rfp.default", "event"=>"click_scan"}, {"input"=>"g", "id"=>203801, "time"=>"2020-07-31T13:53:07.339Z", "state"=>"scanpack.rfp.default", "event"=>"regular"}], "controller"=>"scan_pack", "action"=>"scan_pack_v2", "scan_pack"=>{"_json"=>[{"input"=>"g", "id"=>203801, "time"=>"2020-07-31T13:51:52.955Z", "state"=>"scanpack.rfp.default", "event"=>"click_scan"}, {"input"=>"g", "id"=>203801, "time"=>"2020-07-31T13:53:07.339Z", "state"=>"scanpack.rfp.default", "event"=>"regular"}]}} permitted: false>

    # on_demand_logger = Logger.new("#{Rails.root}/log/log_scan_pack.log")
    # log = { params: params, time: Time.current, params_json: params[:_json] }
    # on_demand_logger.info(log)
    # on_demand_logger.info('---------------------------------------------')
    render json: { status: 'OK', timestamp: (params[:data].last['time'].in_time_zone rescue nil) }
  end

  # takes order_id as input and resets scan status if it is partially scanned.
  def reset_order_scan
    @order = Order.where(id: params[:order_id])
                  .includes(:order_serials, order_items: :product).first
    order_id = params[:order_id]

    if !@order.blank?
      if @order.status != 'scanned'
        @order.reset_scanned_status(current_user)
        @order.destroy_boxes
        @result['data']['next_state'] = 'scanpack.rfo'
        session[:most_recent_scanned_product] = nil
      else
        @result['status'] = false
        @result['error_messages'].push("Order with id: #{order_id} is already in scanned state")
      end
    else
      @result['status'] = false
      @result['error_messages'].push("Could not find order with id: #{order_id}")
    end

    render json: @result
  end

  def serial_scan
    serial_scan_obj = ScanPack::SerialScanService.new(
      current_user, session, params
    )
    render json: serial_scan_obj.run
  end

  def add_note
    add_note_obj = ScanPack::AddNoteService.new(
      current_user, session, params
    )
    render json: add_note_obj.run
  end

  def order_instruction
    # @result = Hash.new
    # @result['status'] = true
    # @result['error_messages'] = []
    # @result['success_messages'] = []
    # @result['notice_messages'] = []
    # @result['data'] = Hash.new

    # if params[:id].blank? || params[:code].blank?
    #   @result['status'] &= false
    #   @result['error_messages'].push('Order id and confirmation code required')
    # else
    #   general_setting = GeneralSetting.all.first
    #   @order = Order.find(params[:id])
    #   if @order.blank?
    #     @result['status'] &= false
    #     @result['error_messages'].push('Could not find order with id: '+params[:id].to_s)
    #   elsif !general_setting.strict_cc || current_user.confirmation_code == params[:code]
    #     @order.addactivity('Order instructions confirmed', current_user.username)
    #   else
    #     @result['status'] &= false
    #     @result['error_messages'].push('Confirmation code doesn\'t match')
    #   end
    # end

    # render json: @result
  end

  def send_request_to_api
    if params[:scan_pack][:_json].present?
      current_tenant = Apartment::Tenant.current
      params[:tenant] =  current_tenant
      scan_pack_object = ScanPack::Base.new
      scan_pack_object.delay(:run_at => 1.seconds.from_now, :queue => "shopakira_request", priority: 95).request_api(params)
    end
    render json: {}
  end

  def order_change_into_scanned
    @result = Hash.new
    order = Order.find(params[:id])
    if !order.nil?
      order.order_items.update_all(scanned_status: "scanned")
      order.addactivity("Order is scanned through SCANNED barcode", current_user.try(:username))
      order.set_order_to_scanned_state(current_user.try(:username))
      @result['status'] = true
      @result['error_messages'] = []
      @result['success_messages'] = []
      @result['notice_messages'] = []
      @result['data'] = Hash.new
      @result['data']['order_complete'] = true
      @result['data']['next_state'] = 'scanpack.rfo'
    else
      @result['status'] = false
    end

    render json: @result
  end

  def click_scan
    render json: product_scan(
        params[:barcode], 'scanpack.rfp.default', params[:id], params[:box_id],
        {
          clicked: true, current_user: current_user, session: session
        }
      ).merge('awaiting' => get_awaiting_orders_count)
  end

  def product_first_scan
    @scanpack_setting = ScanPackSetting.last
    @result = product_first_scan_to_wall(params[:input])
    render json: @result
  end

  def scan_to_tote
    @scanpack_setting = ScanPackSetting.last
    case params[:type]
    when 'assigned_to_tote'
      begin
        tote = params[:tote][:id].present? ? Tote.find(params[:tote][:id]) : Tote.create(params[:tote].permit!)
        order_item = OrderItem.find(params[:order_item_id])
        order = order_item.order
        if tote.order != order
          @result[:status] = false
          @result[:error_messages] = "Whoops! The #{@scanpack_setting.tote_identifier} is already assigned. Please clear the #{@scanpack_setting.tote_identifier} for the order from Orders List and try again."
        elsif tote.name.downcase == params[:tote_barcode].downcase
          if tote.save
            barcode = ProductBarcode.find_by_barcode(params[:barcode_input])
            order.update_attributes(last_suggested_at: DateTime.now)
            order_item.process_item(nil, @current_user.username, 1, nil)
            order.order_activities.last.destroy if order.order_activities.last.present? && (order.order_activities.last.action.include? 'setting the order PENDING')
            order.addactivity("#{@scanpack_setting.tote_identifier} #{tote.name} assignment confirmed with #{@scanpack_setting.tote_identifier} scan.", @current_user.name)
            order.addactivity("Product with barcode: #{barcode.barcode} and sku: #{order_item.product.primary_sku} scanned", @current_user.name)
            tote.update_attributes(pending_order: false)
            @result[:success_messages] = "#{order.increment_id} is successfully assigned to #{@scanpack_setting.tote_identifier}: #{tote.name}"
          end
        else
          @result[:status] = false
          @result[:error_messages] = "Whoops! That’s the wrong #{@scanpack_setting.tote_identifier}. Please scan the correct #{@scanpack_setting.tote_identifier} and then add the item to it."
        end
      rescue => e
        @result[:status] = false
        @result[:error_messages] = e.to_s
      end
    when 'put_in_tote'
      begin
        tote = Tote.find(params[:tote][:id])
        if params[:tote_barcode].downcase == tote.name.downcase
          barcode = ProductBarcode.find_by_barcode(params[:barcode_input])
          order_item = OrderItem.find(params[:order_item_id])
          order = order_item.order
          order.update_attributes(last_suggested_at: DateTime.now)
          order_item.process_item(nil, @current_user.username, 1, nil)
          order.order_activities.last.destroy if order.order_activities.last.present? && (order.order_activities.last.action.include? 'setting the order PENDING')
          order.addactivity("Product with barcode: #{barcode.barcode} and sku: #{order_item.product.primary_sku} scanned", @current_user.name)
          tote.update_attributes(pending_order: false)
          @result[:success_messages] = "#{order_item.product.name} is successfully scanned to #{@scanpack_setting.tote_identifier}: #{tote.name}"
        else
          @result[:status] = false
          @result[:error_messages] = "Whoops! That’s the wrong #{@scanpack_setting.tote_identifier}. Please scan the correct #{@scanpack_setting.tote_identifier} and then add the item to it."
        end
      rescue => e
        @result[:status] = false
        @result[:error_messages] = e.to_s
      end
    when 'scan_tote_to_complete'
      begin
        tote = Tote.find(params[:tote][:id])
        order_item = OrderItem.find(params[:order_item_id])
        order = order_item.order
        if order.status == 'scanned'
          @result[:status] = false
          @result[:error_messages] = "Order ##{order.increment_id} is already scanned"
        elsif params[:tote_barcode].downcase == tote.name.downcase
          barcode = ProductBarcode.find_by_barcode(params[:barcode_input])
          order_item.process_item(nil, @current_user.username, 1, nil)
          order.order_activities.last.destroy if order.order_activities.last.present? && (order.order_activities.last.action.include? 'setting the order PENDING')
          order.addactivity("Product with barcode: #{barcode.barcode} and sku: #{order_item.product.primary_sku} scanned", @current_user.name)
          order.set_order_to_scanned_state(@current_user.username)
          order.update_attributes(last_suggested_at: DateTime.now)
          @result[:success_messages] = "#{order.increment_id} is successfully scanned"
          @result[:scan_tote_to_completed] = true
          @result[:multi_item_order_message] = @scanpack_setting.multi_item_order_complete_msg
          @result[:multi_item_order_message_time] = @scanpack_setting.multi_item_order_complete_msg_time
          @result[:store_type] = order.store.store_type
          @result[:popup_shipping_label] = order.store.shipping_easy_credential.popup_shipping_label rescue nil
          @result[:large_popup] = order.store.shipping_easy_credential.large_popup rescue nil
          ScanPack::ScanBarcodeService.new(current_user, session, params).generate_order_barcode_slip(order) if @scanpack_setting.post_scanning_option == 'Barcode' && !@result[:popup_shipping_label]
          @result[:order_items_scanned] = order.get_scanned_items.select { |item| item['qty_remaining'] == 0 }
          @result[:order_items_unscanned] = []
          @result[:order_items_partial_scanned] = []
          @result[:tote_name_identifier] = @scanpack_setting.tote_identifier + ' ' + tote.name
          @result[:order] = order
          tote.update_attributes(order_id: nil, pending_order: false)
        else
          @result[:status] = false
          @result[:error_messages] = "Whoops! That’s the wrong #{@scanpack_setting.tote_identifier}. Please scan the correct #{@scanpack_setting.tote_identifier} and then add the item to it."
        end
      rescue => e
        @result[:status] = false
        @result[:error_messages] = e.to_s
      end
    end
    render json: @result
  end

  def confirmation_code
    general_setting = GeneralSetting.first
    render json: {confirmed: (!general_setting.strict_cc || current_user.confirmation_code == params[:code])}
  end

  def type_scan
    type_scan_obj = ScanPack::TypeScanService.new(
      current_user, session, params
    )
    render json: type_scan_obj.run
  end

  def product_instruction
    product_instruction_obj = ScanPack::ProductInstructionService.new(
      current_user, session, params
    )
    render json: product_instruction_obj.run
  end

  def get_shipment
    result = {}
    filters = {includes: "products", id: params["order_id"].to_i} rescue nil
    filters = filters.merge(get_cred(params["store_id"]))
    response = ::ShippingEasy::Resources::Order.find(filters) rescue nil
    result[:shipment_id] = response["order"]["shipments"][0]["id"] rescue nil
    render json: result
  end

  def update_scanned
    order = Order.find_by_increment_id(params["increment_id"])
    if order.present?
      order.already_scanned =  true
      order.save
    else
      @result["notice_messages"] = "Order not found"
    end
    render json: @result
  end

  private

  def get_cred(store_id)
    cred = ShippingEasyCredential.find_by_store_id(store_id) rescue nil
    return response = {api_key: cred.api_key, api_secret: cred.api_secret}
  end

  def set_result_instance
    @result = {
      "status" => true, "error_messages" => [], "success_messages" => [],
      "notice_messages" => [], 'data' => {}, 'awaiting' => get_awaiting_orders_count
    }
  end

  def get_awaiting_orders_count
    Order.where(status: 'awaiting').count
  end
end
