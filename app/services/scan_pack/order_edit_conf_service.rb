class ScanPack::OrderEditConfService < ScanPack::Base
  def initialize(args)
    @session, @input, @state, @id = args
    @result = {
      "status"=>true,
      "matched"=>false,
      "error_messages"=>[],
      "success_messages"=>[],
      "notice_messages"=>[],
      "data"=>{}
    }
    @single_order = Order.where(id: @id).last
  end

  def run
    case true
    when @id.blank? || @input.blank?
      set_error_messages("Please specify confirmation code and order id to confirm purchase code")
    when @single_order.blank?
      set_error_messages("Could not find order with id: "+@id.to_s)
    else
      order_edit_conf
    end
    @result
  end

  def order_edit_conf
    @result['data']['order_num'] = @single_order.increment_id
    if @single_order.status == "onhold" && !@single_order.has_inactive_or_new_products
      if User.where(:confirmation_code => @input).length > 0
        @result['matched'] = true
        @single_order.status = 'awaiting'
        @single_order.addactivity("Status changed from onhold to awaiting",
                                 User.where(:confirmation_code => @input).first.username)
        @single_order.save
        @result['data']['scanned_on'] = @single_order.scanned_on
        @result['data']['next_state'] = 'scanpack.rfp.default'
        @session[:order_edit_matched_for_current_user] = true
      else
        @result['data']['next_state'] = 'scanpack.rfo'
      end
    else
      set_error_messages(
        "Only orders with status On Hold and has inactive or new products "\
        "can use edit confirmation code."
      )
    end
    @result['data']['order'] = order_details_and_next_item
  end
end #class end