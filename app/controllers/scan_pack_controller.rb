class ScanPackController < ApplicationController
  before_action :groovepacker_authorize!, :set_result_instance
  include ScanPackHelper

  def scan_barcode
    scan_barcode_obj = ScanPack::ScanBarcodeService.new(
      current_user, session, params
    )
    render json: scan_barcode_obj.run.merge('awaiting' => get_awaiting_orders_count)
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
      scan_pack_object.delay(:run_at => 1.seconds.from_now, :queue => "shopakira_request").request_api(params)
    end
    render json: {}
  end

  def order_change_into_scanned
    @result = Hash.new
    order = Order.find(params[:id])
    if !order.nil?
      order.order_items.update_all(scanned_status: "scanned")
      current_user_name = current_user.try(:username)
      order.addactivity("Order is scanned through SCANNED barcode",current_user_name)
      order.set_order_to_scanned_state(current_user_name)
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
        if tote.name.downcase == params[:tote_barcode].downcase
          order_item = OrderItem.find(params[:order_item_id])
          tote.order = order_item.order
          if tote.save
            order = order_item.order
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
