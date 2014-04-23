class ScanPackController < ApplicationController
  before_filter :authenticate_user!
  include ScanPackHelper


  def scan_barcode
    @result = Hash.new
    @result['error_messages'] = []
    @result['success_messages'] = []
    @result['notice_messages'] = []

    @matcher = {
        'scanpack.rfo' => ['order_scan'],
        'scanpack.rfp.default' => ['product_scan'],
        'scanpack.rfp.tracking' => ['scan_tracking'],
        'scanpack.rfp.product_edit' => ['order_scan'],
        'scanpack.rfp.confirmation.product_edit' => ['product_edit_conf','order_scan'],
        'scanpack.rfp.confirmation.order_edit' => ['order_edit_conf','order_scan'],
        'scanpack.rfp.confirmation.cos' => ['cos_conf','order_scan']
    }

    if !params[:input].nil? && !params[:state].nil?
      @matcher[params[:state]].each do |state_func|
        output = send(state_func,params[:input],params[:state],params[:id])
        @result['error_messages'] = @result['error_messages'] + output['error_messages']
        @result['success_messages'] = @result['success_messages'] + output['success_messages']
        @result['notice_messages'] = @result['notice_messages'] + output['notice_messages']
        @result['status'] = output['status']
        @result['data'] = output['data']
        break if output["matched"]
      end

    end

    @result['paramm']= params

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end

  # takes order_id as input and resets scan status if it is partially scanned.
  def reset_order_scan
    @result = Hash.new
    @result['status'] = true
    @result['error_messages'] = []
    @result['success_messages'] = []
    @result['notice_messages'] = []
    @result['data'] = Hash.new

    @order = Order.find(params[:order_id])

    if !@order.nil?
      if @order.status != 'scanned'
        @order.reset_scanned_status
        @result['data']['next_state'] = 'scanpack.rfo'
      else
        @result['status'] &= false
        @result['error_messages'].push("Order with id: "+params[:order_id]+" is already in scanned state")
      end
    else
      @result['status'] &= false
      @result['error_messages'].push("Could not find order with id: "+params[:order_id])
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end


  def order_instruction
    @result = Hash.new
    @result['status'] = true
    @result['error_messages'] = []
    @result['success_messages'] = []
    @result['notice_messages'] = []
    @result['data'] = Hash.new

    if params[:id].nil? || params[:code].nil?
      @result['status'] &= false
      @result['error_messages'].push("Order id and confirmation code required")
    else
      @order = Order.find(params[:id])
      if @order.nil?
        @result['status'] &= false
        @result['error_messages'].push("Could not find order with id: "+params[:id].to_s)
      elsif current_user.confirmation_code == params[:code]
        @order.addactivity("Order instructions confirmed", current_user.username)
      else
        @result['status'] &= false
        @result['error_messages'].push("Confirmation code doesn't match")
      end
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end

  def product_instruction
    @result = Hash.new
    @result['status'] = true
    @result['error_messages'] = []
    @result['success_messages'] = []
    @result['notice_messages'] = []
    @result['data'] = Hash.new

    if params[:id].nil? || params[:code].nil?
      @result['status'] &= false
      @result['error_messages'].push("Order id and confirmation code required")
    else
      @order = Order.find(params[:id])
      if params[:next_item]['kit_product_id'].nil?
        @order_item = OrderItem.find(params[:next_item]['order_item_id'])
      else
        @order_item = OrderItemKitProduct.find(params[:next_item]['kit_product_id'])
      end

      if @order.nil?
        @result['status'] &= false
        @result['error_messages'].push("Could not find order with id: "+params[:id].to_s)
      elsif current_user.confirmation_code == params[:code]
        @order.addactivity("Next item", current_user.username)
      else
        @result['status'] &= false
        @result['error_messages'].push("Confirmation code doesn't match")
      end
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end



end
