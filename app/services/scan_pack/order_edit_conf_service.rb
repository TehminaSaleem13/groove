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
    order_edit_conf
    @result
  end

  def order_edit_conf
    if !@id.nil? || !@input.nil?
      #check if order status is On Hold
      if @single_order.nil?
        @result['status'] &= false
        @result['error_messages'].push("Could not find order with id: "+@id.to_s)
      else
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
          @result['status'] &= false
          @result['error_messages'].push("Only orders with status On Hold and has inactive or new products "+
                                          "can use edit confirmation code.")
        end
        @result['data']['order'] = order_details_and_next_item
      end

      #check if current user edit confirmation code is same as that entered
    else
      @result['status'] &= false
      @result['error_messages'].push("Please specify confirmation code and order id to confirm purchase code")
    end
  end
end #class end