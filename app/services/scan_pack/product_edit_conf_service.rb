class ScanPack::ProductEditConfService < ScanPack::Base
  # For initialisation and run functionality
  include ScanPack::Utilities::ConfCommon

  def product_edit_conf
    result_data = @result['data']
    if @single_order.status == "onhold" && @single_order.has_inactive_or_new_products
      if User.where(:confirmation_code => @input).length > 0
        user = User.where(:confirmation_code => @input).first
        if user.can? 'add_edit_products'
          do_if_user_can_add_edit_products
        else
          result_data['next_state'] = 'scanpack.rfp.confirmation.product_edit'
          @result['matched'] = true
          @result['error_messages'].push(
            "User with confirmation code #{@input}"\
            " does not have permission for editing products."
          )
        end
      else
        result_data['next_state'] = 'scanpack.rfo'
      end
    else
      set_error_messages(
        "Only orders with status On Hold and has inactive or new products "\
        "can use edit confirmation code."
      )
    end
    @result['data']['order'] = order_details_and_next_item
  end

  def do_if_user_can_add_edit_products
    result_data = @result['data']
    @result['matched'] = true
    result_data['inactive_or_new_products'] = @single_order.get_inactive_or_new_products
    result_data['next_state'] = 'scanpack.rfp.product_edit'
    @session[:product_edit_matched_for_current_user] = true
    @session[:product_edit_matched_for_products] = []
    result_data['inactive_or_new_products'].each do |inactive_new_product|
      @session[:product_edit_matched_for_products].push(inactive_new_product.id)
    end
    @session[:product_edit_matched_for_order] = @single_order.id
  end
  
end