class ScanPack::ScanVerifyingService < ScanPack::Base
  def initialize(args)
    @current_user, @input, @id = args
    @result = {
      "status"=>true,
      "matched"=>false,
      "error_messages"=>[],
      "success_messages"=>[],
      "notice_messages"=>[],
      "data"=>{
        'next_state' => 'scanpack.rfp.verifying'
      }
    }
    @order = Order.where(id: @id).last
  end
  
  def run
    case true
    when @order.blank?
      set_error_messages("Could not find order with id: "+ @id.to_s)
    when @order.status != 'awaiting'
      set_error_messages("The order is not in awaiting state. Cannot scan the tracking number")
    else
      scan_verifying
    end
    @result
  end

  def scan_verifying
    tracking_num = @order.tracking_num.try(:gsub, /^(\#*)/, '').try{|a| a.gsub(/(\W)/){|c| "\\#{c}"}}
    case true
    when @input.present? && tracking_num && @input.match(/#{tracking_num}/).present?
      do_if_tracking_number_eql_input
    when @input.present? && (@input == @current_user.confirmation_code)
      do_if_input_eql_confirmation_code
    else
      set_error_messages("Tracking number does not match.")
      @result['data']['next_state'] = 'scanpack.rfp.no_match'
    end
  end

  def do_if_tracking_number_eql_input
    @order.set_order_to_scanned_state(@current_user.username)
    @result['data'].merge!({
      'order_complete'=> true,
      'next_state'=> 'scanpack.rfo'
      })
    @order.addactivity("Shipping Label Verified: #{@order.tracking_num}", @current_user.username)
    @order.save
  end

  def do_if_input_eql_confirmation_code
    @result['matched'] = false
    @order.set_order_to_scanned_state(@current_user.username)
    @result['data'].merge!({
      'order_complete'=> true,
      'next_state'=> 'scanpack.rfo'
      })
    @order.save
  end

end