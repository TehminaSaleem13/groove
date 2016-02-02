class ScanPack::OrderEditConfService < ScanPack::Base
  # For initialisation and run functionality
  include ScanPack::Utilities::ConfCommon
  
  def order_edit_conf
    @result['data']['order_num'] = @single_order.increment_id
    if @single_order.status == "onhold" && !@single_order.has_inactive_or_new_products
      if User.where(:confirmation_code => @input).any?
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