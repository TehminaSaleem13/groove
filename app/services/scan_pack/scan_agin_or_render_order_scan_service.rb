class ScanPack::ScanAginOrRenderOrderScanService < ScanPack::Base
  def initialize(args)
    @current_user, @input, @state, @id = args
    @result = {
      "status"=>true,
      "matched"=>false,
      "error_messages"=>[],
      "success_messages"=>[],
      "notice_messages"=>[],
      "data"=>{
        'next_state' => 'scanpack.rfp.no_match'
      }
    }
    @order = Order.where(id: @id).last
  end
  
  def run
    scan_again_or_render_order_scan if @order.present?
    @result
  end

  def scan_again_or_render_order_scan
    tracking_num = @order.tracking_num.try(:gsub, /^(\#*)/, '').try{|a| a.gsub(/(\W)/){|c| "\\#{c}"}}
    no_match_state = @state == "scanpack.rfp.no_match"
    case true
    when no_match_state && @input == @current_user.confirmation_code
      do_if_confirmation_code_eql_input
    when no_match_state && tracking_num && @input.match(/#{tracking_num}/).present?
      do_if_input_eql_tracking_num
    when no_match_state && @input == "" && GeneralSetting.all.first.strict_cc == false
      do_if_input_is_empty_and_strict_cc_false
    else
      @result['status'] = false
      @result['matched'] = false
      @result['data']['next_state'] = 'scanpack.rfp.no_match'
    end
  end

  def do_if_confirmation_code_eql_input
    @result['status'] = true
    @result['matched'] = false
    @order.set_order_to_scanned_state(@current_user.username)
    @result['data']['order_complete'] = true
    @order.addactivity(
      "The correct shipping label was not verified at the time of packing."\
      " Confirmation code for user #{@current_user.username} was scanned",
      @current_user.username
      )
    @result['data']['next_state'] = 'scanpack.rfo'
    @order.save
  end

  def do_if_input_eql_tracking_num
    @result['status'] = true
    @result['matched'] = true
    @order.set_order_to_scanned_state(@current_user.username)
    @result['data']['order_complete'] = true
    @result['data']['next_state'] = 'scanpack.rfo'
    @order.save
  end

  def do_if_input_is_empty_and_strict_cc_false
    @result['status'] = true
    @result['matched'] = false
    @order.set_order_to_scanned_state(@current_user.username)
    @result['data']['order_complete'] = true
    @result['data']['next_state'] = 'scanpack.rfo'
  end
end