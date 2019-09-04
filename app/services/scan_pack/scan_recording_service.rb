class ScanPack::ScanRecordingService < ScanPack::Base
  def initialize(args)
    @current_user, @input, @id = args
    @result = {
      "status"=>true,
      "matched"=>false,
      "error_messages"=>[],
      "success_messages"=>[],
      "notice_messages"=>[],
      "data"=>{}
    }
    @order = Order.where(id: @id).last
    @scanpack_settings_post_scanning_option_second = ScanPackSetting.last.post_scanning_option_second
  end

  def run
    case true
    when @input.blank?
      set_error_messages("No tracking number is provided")
    when @order.blank?
      set_error_messages("Could not find order with id: "+ @id.to_s)
    else
      scan_recording
    end
    @result
  end

  def scan_recording
    @result['data']['next_state'] = 'scanpack.rfp.recording'
    if @order.status == 'awaiting'
      #allow tracking id to be saved without special permissions
      if @scanpack_settings_post_scanning_option_second == "None" || @scanpack_settings_post_scanning_option_second == "Record" 
        @order.tracking_num = @input
        @order.set_order_to_scanned_state(@current_user.username)
        @result['data']['order_complete'] = true
        @result['data']['next_state'] = 'scanpack.rfo'
        #update inventory when inventory warehouses is implemented.
        @order.save
      else
        @order.tracking_num = @input
        @order.save
        apply_second_action
      end  
    else
      set_error_messages("The order is not in awaiting state. Cannot scan the tracking number")
    end
  end
  
  def apply_second_action
    case @scanpack_settings_post_scanning_option_second
      when "Verify"
        unless @order.tracking_num.present?
          @result['data']['next_state'] = 'scanpack.rfp.no_tracking_info'
          @order.addactivity("Tracking information was not imported with this order so the shipping label could not be verified ", @current_user.username)
        else
          @result['data']['next_state'] = 'scanpack.rfp.verifying'
        end
      when "PackingSlip"
        do_set_order_scanned_state_and_result_data
        generate_packing_slip(@order)
      when "Barcode"
        do_set_order_scanned_state_and_result_data
        generate_order_barcode_slip(@order)
      else
        do_set_order_scanned_state_and_result_data
      end
  end

  def do_set_order_scanned_state_and_result_data
    @order.set_order_to_scanned_state(@current_user.username)
    @result['data']['order_complete'] = true
    @result['data']['next_state'] = 'scanpack.rfo'
  end
end