class ScanPack::RenderOrderScanService < ScanPack::Base
  def initialize(args)
    @current_user, @input, @state, @id = args
    @result = {
      "status"=>true,
      "matched"=>false,
      "error_messages"=>[],
      "success_messages"=>[],
      "notice_messages"=>[],
      "data"=>{
        'next_state' => 'scanpack.rfp.no_tracking_info'
      }
    }
    @scanpack_settings_post_scanning_option_second = ScanPackSetting.last.post_scanning_option_second
  end
  
  def run
    render_order_scan if @id.present?
    @result
  end

  def render_order_scan
    order = Order.where(id: @id).last
    if @state == "scanpack.rfp.no_tracking_info" && (@input == @current_user.confirmation_code || @input == "")
      if @scanpack_settings_post_scanning_option_second == "None" || @scanpack_settings_post_scanning_option_second == "Verify" 
        @result['status'] = true
        @result['matched'] = false
        order.set_order_to_scanned_state(@current_user.username)
        @result['data']['order_complete'] = true
        @result['data']['next_state'] = 'scanpack.rfo'
        order.save
      else
        order.update_columns(post_scanning_flag: 'Verify')
        apply_second_action
      end  
    else
      @result['status'] = false
      @result['matched'] = false
      @result['data']['next_state'] = 'scanpack.rfp.no_tracking_info'
    end
  end

  def apply_second_action
    order = Order.where(id: @id).last
    case @scanpack_settings_post_scanning_option_second
    when "Record"
      @result['data']['next_state'] = 'scanpack.rfp.recording'
    when "PackingSlip"
      do_set_order_scanned_state_and_result_data
      generate_packing_slip(order)
    when "Barcode"
      do_set_order_scanned_state_and_result_data
      generate_order_barcode_slip(order)
    else
      do_set_order_scanned_state_and_result_data
    end
  end

  def do_set_order_scanned_state_and_result_data
    order.set_order_to_scanned_state(@current_user.username)
    @result['data']['order_complete'] = true
    @result['data']['next_state'] = 'scanpack.rfo'
  end
  
end