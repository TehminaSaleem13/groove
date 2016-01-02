class ScanPack::CosConfService < ScanPack::Base
  include ScanPack::Utilities::ConfCommon

  def cos_conf
    @result['data']['order_num'] = @single_order.increment_id
    if @single_order.status == "serviceissue"
      if User.where(:confirmation_code => @input).length > 0
        user = User.where(:confirmation_code => @input).first

        if user.can?('change_order_status')
          #set order state to awaiting scannus
          @single_order.status = 'awaiting'
          @single_order.save
          @single_order.update_order_status
          @result['matched'] = true
          #set next state
          @result['data']['next_state'] = 'scanpack.rfp.default'
        else
          @result['matched'] = true
          @result['data']['next_state'] = 'scanpack.rfp.confirmation.cos'
          @result['error_messages'].push(
            "User with confirmation code: #{@input} does not have permission to change order status"
            )
        end
      else
        @result['data']['next_state'] = 'scanpack.rfp.confirmation.cos'
        @result['error_messages'].push("Could not find any user with confirmation code")
      end
    else
      set_error_messages(
        "Only orders with status Service issue"\
        "can use change of status confirmation code"
      )
    end
    @result['data']['order'] = order_details_and_next_item
  end
end