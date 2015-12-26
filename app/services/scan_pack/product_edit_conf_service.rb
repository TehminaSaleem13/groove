class ScanPack::ProductEditConfService < ScanPack::Base
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
      product_edit_conf
    end
    @result
  end

  def product_edit_conf
    if @single_order.status == "onhold" && @single_order.has_inactive_or_new_products
      if User.where(:confirmation_code => @input).length > 0
        user = User.where(:confirmation_code => @input).first
        if user.can? 'add_edit_products'
          do_if_user_can_add_edit_products
        else
          @result['data']['next_state'] = 'scanpack.rfp.confirmation.product_edit'
          @result['matched'] = true
          @result['error_messages'].push(
            "User with confirmation code #{@input}"\
            " does not have permission for editing products."
          )
        end
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

  def do_if_user_can_add_edit_products
    @result['matched'] = true
    @result['data']['inactive_or_new_products'] = @single_order.get_inactive_or_new_products
    @result['data']['next_state'] = 'scanpack.rfp.product_edit'
    @session[:product_edit_matched_for_current_user] = true
    @session[:product_edit_matched_for_products] = []
    @result['data']['inactive_or_new_products'].each do |inactive_new_product|
      @session[:product_edit_matched_for_products].push(inactive_new_product.id)
    end
    @session[:product_edit_matched_for_order] = @single_order.id
  end
  
end