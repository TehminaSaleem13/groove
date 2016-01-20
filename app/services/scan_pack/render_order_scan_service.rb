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
  end
  
  def run
    render_order_scan if @id.present?
    @result
  end

  def render_order_scan
    order = Order.where(id: @id).last
    if @state == "scanpack.rfp.no_tracking_info" && (@input == @current_user.confirmation_code || @input == "")
      @result['status'] = true
      @result['matched'] = false
      order.set_order_to_scanned_state(@current_user.username)
      @result['data']['order_complete'] = true
      @result['data']['next_state'] = 'scanpack.rfo'
      order.save
    else
      @result['status'] = false
      @result['matched'] = false
      @result['data']['next_state'] = 'scanpack.rfp.no_tracking_info'
    end
  end
  
end