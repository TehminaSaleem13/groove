class ScanPack::CosConfService < ScanPack::Base
  include ScanPack::Utilities::ConfCommon

  def cos_conf
    data = @result['data']
    data['order_num'] = @single_order.increment_id
    user = User.where(:confirmation_code => @input).first
    
    if @single_order.status == "serviceissue"
      if user
        if user.can?('change_order_status')
          #set order state to awaiting scannus
          @single_order.status = 'awaiting'
          @single_order.save
          @single_order.update_order_status
          @result['matched'] = true
          #set next state
          next_state = 'scanpack.rfp.default'
          error_messages = []
        else
          @result['matched'] = true
          next_state = 'scanpack.rfp.confirmation.cos'
          error_messages = ["User with confirmation code: #{@input} does not have permission to change order status"]
        end
      else
        next_state = 'scanpack.rfp.confirmation.cos'
        error_messages = ["Could not find any user with confirmation code"]
      end
      data['next_state'] = next_state
      @result['error_messages'].push(*error_messages)
    else
      set_error_messages(
        "Only orders with status Service issue"\
        "can use change of status confirmation code"
      )
    end
    
    data['order'] = order_details_and_next_item
  end
end