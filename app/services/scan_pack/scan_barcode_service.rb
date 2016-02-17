module ScanPack
  class ScanBarcodeService
    include ScanPackHelper
    
    def initialize(*args)
      @params, @current_user, @session = *args
      @result = {
        "status" => true, "error_messages" => [], "success_messages" => [],
        "notice_messages" => [], 'data' => {}
      }
    end

    def run
      unless @params[:state].present?
        @result['status'] &= false
        @result['error_messages'].push("Please specify a state")
      else
        scan_barcode
      end
      @result
    end

    def scan_barcode
      do_set_state_matcher
      do_scan_now
      do_check_state_and_status_to_add_activity
    end

    def do_set_state_matcher
      @matcher = {
        'scanpack.rfo' => ['order_scan'],
        'scanpack.rfp.default' => ['product_scan'],
        'scanpack.rfp.recording' => ['scan_recording'],
        'scanpack.rfp.verifying' => ['scan_verifying'],
        'scanpack.rfp.no_tracking_info' => ['render_order_scan'],
        'scanpack.rfp.no_match' => ['scan_again_or_render_order_scan'],
        'scanpack.rfp.product_edit' => ['order_scan'],
        'scanpack.rfp.product_edit.single' => ['order_scan'],
        'scanpack.rfp.confirmation.product_edit' => ['product_edit_conf', 'order_scan'],
        'scanpack.rfp.confirmation.order_edit' => ['order_edit_conf', 'order_scan'],
        'scanpack.rfp.confirmation.cos' => ['cos_conf', 'order_scan']
      }
    end

    def do_scan_now
      @matcher[@params[:state]].each do |state_func|
        output = send(
          state_func, @params[:input], @params[:state], @params[:id],
          {
            current_user: @current_user, session: @session
          }
        )
        do_set_result(output)
        break if output["matched"]
      end
    end

    def do_set_result(output)
      @result['error_messages'].push *output['error_messages']
      @result['success_messages'].push *output['success_messages']
      @result['notice_messages'].push *output['notice_messages']
      @result['status'] = output['status']
      @result['data'] = output['data']
      @result['matched'] = output['matched']
    end

    def do_check_state_and_status_to_add_activity
      if @params[:state] == "scanpack.rfp.default" && @result['status'] == true
        Order.find(@params[:id]).addactivity("Product with barcode: #{@params[:input]} scanned", @current_user.name)
      end
    end
  end
end