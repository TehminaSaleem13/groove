# frozen_string_literal: true

class ScanPackController < ApplicationController
  before_action :groovepacker_authorize!, :set_result_instance
  include ScanPackHelper

  def scan_pack_bug_report
    data = params.to_unsafe_hash
    data[:url] = create_log_file_data(data, :logs, 'expo_bugs') if data[:logs].present?
    BugReportMailer.delay(priority: 95).report_bug(data.except(:scan_pack, :logs), current_user.try(:username), Apartment::Tenant.current)
    render json: { status: 'OK' }
  end

  def scan_barcode
    scan_barcode_obj = ScanPack::ScanBarcodeService.new(
      current_user, session, params
    )
    render json: scan_barcode_obj.run.merge('awaiting' => get_awaiting_orders_count)
  end

  def scan_pack_v2
    current_timestamp = begin
                          params[:data].last['time'].in_time_zone
                        rescue StandardError
                          nil
                        end
    if params[:data].present?
      tenant = Tenant.find_by_name(Apartment::Tenant.current)
      log_scn_obj = Groovepacker::ScanPackV2::LogScanService.new
      if tenant.expo_logs_delay
        params[:data] = create_log_file_data(params, :data, 'expo_log_data')
        params[:delayed_log_process] = true
        session = session.present? ? session : nil
        @result = log_scn_obj.delay(run_at: 1.seconds.from_now, priority: 95).process_logs(tenant.name, current_user.try(:id), session, params.except(:scan_pack))
      else
        @result = log_scn_obj.process_logs(tenant.name, current_user.try(:id), session, params.except(:scan_pack))
      end
    end

    if(@result.present? && !@result['status'])
      render json: { response: params[:data]&.first, status: :internal_server_error }
    else
      render json: { response: params[:data]&.first, status: 'OK', timestamp: current_timestamp }
    end
  end

  def detect_discrepancy
    orders_data = params[:data]
    @orders = Order.where(id: orders_data.pluck(:order_id))
    @result = []

    @orders.each do |order|
      local_order = orders_data.find { |s| s[:order_id].to_s == order.id.to_s }
      order_status_code = order.status == 'scanned' ? 0 : nil

      if local_order && local_order[:status].to_s != order_status_code.to_s
        options = { order_id: order.id, user_name: current_user.name, app_url: params[:app_url] }
        service = Groovepacker::SlackNotifications::OrderScanDiscrepancy.new(Apartment::Tenant.current, options)
        service.delay(run_at: 15.seconds.from_now, priority: 95).call
        local_order[:discrepancy] = true
        @result << local_order
      else
        local_order[:discrepancy] = false
        @result << local_order
      end
    end

    render json: { result: @result, status: 'OK' }
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
      params[:tenant] = current_tenant
      scan_pack_object = ScanPack::Base.new
      scan_pack_object.delay(run_at: 1.seconds.from_now, queue: 'shopakira_request', priority: 95).request_api(params)
    end
    render json: {}
  end

  def order_change_into_scanned
    @result = {}
    order = Order.find(params[:id])
    if !order.nil?
      order.order_items.update_all(scanned_status: 'scanned')
      order.addactivity('Order is scanned through SCANNED barcode', current_user.try(:username))
      order.set_order_to_scanned_state(current_user.try(:username))
      @result['status'] = true
      @result['error_messages'] = []
      @result['success_messages'] = []
      @result['notice_messages'] = []
      @result['data'] = {}
      @result['data']['order_complete'] = true
      @result['data']['next_state'] = 'scanpack.rfo'
    else
      @result['status'] = false
    end

    render json: @result
  end

  def click_scan
    render json: product_scan(
      params[:barcode], 'scanpack.rfp.default', params[:id], params[:box_id], params[:on_ex],
      clicked: true, current_user: current_user, session: session
    ).merge('awaiting' => get_awaiting_orders_count)
  end

  def product_first_scan
    product_first_scan = ScanPack::ProductFirstScan::OrderScanService.new(
      current_user, session, params
    )
    render json: product_first_scan.run
  end

  def scan_to_tote
    product_first_scan = ScanPack::ProductFirstScan::ProductScanService.new(
      current_user, session, params
    )
    render json: product_first_scan.run
  end

  def confirmation_code
    general_setting = GeneralSetting.first
    render json: { confirmed: (!general_setting.strict_cc || current_user.confirmation_code == params[:code]) }
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
    filters = begin
                { includes: 'products', id: params['order_id'].to_i }
              rescue StandardError
                nil
              end
    filters = filters.merge(get_cred(params['store_id']))
    response = begin
                 ::ShippingEasy::Resources::Order.find(filters)
               rescue StandardError
                 nil
               end
    result[:shipment_id] = begin
                             response['order']['shipments'][0]['id']
                           rescue StandardError
                             nil
                           end
    render json: result
  end

  def update_scanned
    order = Order.find_by_increment_id(params['increment_id'])
    if order.present?
      order.already_scanned = true
      order.save
    else
      @result['notice_messages'] = 'Order not found'
    end
    render json: @result
  end

  def verify_order_scanning
    options = { order_id: params[:id], request_ip: request.remote_ip, current_user: current_user.username, app_url: params[:app_url] }
    service = Groovepacker::Orders::Verification::CheckUnscanned.new(Apartment::Tenant.current, options)
    service.delay(run_at: 15.seconds.from_now, priority: 95).call
    head :ok
  end

  def upload_image_on_s3
    result = { status: true }
    begin
      order = Order.find(params[:order_id])
      if params[:base_64_img_upload].present?
        current_tenant = Apartment::Tenant.current
        image_content = Base64.decode64(params[:image][:image].to_s)
        content_type = params[:image][:content_type]
        file_name = "packing_cams/#{SecureRandom.random_number(20_000)}_#{Time.current.strftime('%d_%b_%Y_%I__%M_%p')}_#{current_tenant}_#{order.id}_" + params[:image][:original_filename].delete('#')
        GroovS3.create_image(current_tenant, file_name, image_content, content_type)

        url = ENV['S3_BASE_URL'] + '/' + current_tenant + '/image/' + file_name
        packing_cam = order.packing_cams.create(url: url, user: current_user, username: current_user&.username)
        result[:image] = packing_cam
      end
    rescue StandardError => e
      result[:error] = e.message
      result[:status] = false
    end
    render json: result
  end

  private

  def get_cred(store_id)
    cred = begin
             ShippingEasyCredential.find_by_store_id(store_id)
           rescue StandardError
             nil
           end
    response = { api_key: cred.api_key, api_secret: cred.api_secret }
  end

  def set_result_instance
    @result = {
      'status' => true, 'error_messages' => [], 'success_messages' => [],
      'notice_messages' => [], 'data' => {}, 'awaiting' => get_awaiting_orders_count
    }
  end

  def get_awaiting_orders_count
    Order.where(status: 'awaiting').count
  end
end
