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
      @order.tracking_num = @input
      @order.set_order_to_scanned_state(@current_user.username)
      @result['data']['order_complete'] = true
      @result['data']['next_state'] = 'scanpack.rfo'
      #update inventory when inventory warehouses is implemented.
      @order.save
    else
      set_error_messages("The order is not in awaiting state. Cannot scan the tracking number")
    end
  end

end