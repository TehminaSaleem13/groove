class ScanPackController < ApplicationController
  before_filter :authenticate_user!
  include ScanPackHelper


  def scan_barcode
    @result = Hash.new
    @result['status'] = true
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

    if params[:state].nil?
      @result['status'] &= false
      @result['error_messages'].push("Please specify a state")
    else
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

  def add_note
    @result = Hash.new
    @result['status'] = true
    @result['error_messages'] = []
    @result['success_messages'] = []
    @result['notice_messages'] = []
    email = !params[:email].blank?
    if params[:id].nil? || params[:note].nil?
      @result['status'] &= false
      @result['error_messages'].push('Order id and note from packer required')
    else
      @order = Order.find(params[:id])
      if @order.nil?
        @result['status'] &= false
        @result['error_messages'].push('Could not find order with id: '+params[:id].to_s)
      else
        @order.notes_fromPacker = params[:note].to_s
        if @order.save
          @result['success_messages'].push('Note from Packer saved successfully')
          general_settings = GeneralSetting.all.first
          if general_settings.send_email_for_packer_notes == 'always' ||
              (general_settings.send_email_for_packer_notes == 'optional' && email)
            #send email
            mail_settings = Hash.new
            mail_settings['email'] = general_settings.email_address_for_packer_notes
            mail_settings['sender'] = current_user.name + ' ('+current_user.username+')'
            mail_settings['tenant_name'] = Apartment::Tenant.current_tenant
            mail_settings['order_number'] = @order.increment_id
            mail_settings['order_id'] = @order.id
            mail_settings['note_from_packer'] = @order.notes_fromPacker

            NotesFromPacker.send_email(mail_settings).deliver
          end
        else
          @result['status'] &= false
          @result['error_messages'].push('There was an error saving note from packer, please try again')
        end
      end
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

  def click_scan
    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: product_scan(params[:barcode],'scanpack.rfp.default',params[:id],true) }
    end
  end

  def product_instruction
    @result = Hash.new
    @result['status'] = true
    @result['error_messages'] = []
    @result['success_messages'] = []
    @result['notice_messages'] = []
    @result['data'] = Hash.new

    if params[:id].nil? || params[:code].nil? || params[:next_item].nil?
      @result['status'] &= false
      @result['error_messages'].push("Order id and confirmation code required")
    else
      @order = Order.find(params[:id])

      if @order.nil?
        @result['status'] &= false
        @result['error_messages'].push("Could not find order with id: "+params[:id].to_s)
      elsif current_user.confirmation_code == params[:code]
        @order_item = OrderItem.find(params[:next_item]['order_item_id'])
        unless params[:next_item]['kit_product_id'].nil?
          @order_kit_product = OrderItemKitProduct.find(params[:next_item]['kit_product_id'])
        end
        if @order_item.nil?
          @result['status'] &= false
          @result['error_messages'].push("Couldnt find order item")
        elsif !params[:next_item]['kit_product_id'].nil? && (@order_kit_product.nil?  ||
            @order_kit_product.order_item_id != @order_item.id)
          @result['status'] &= false
          @result['error_messages'].push("Couldnt find child item")
        elsif @order_item.order_id != @order.id
          @result['status'] &= false
          @result['error_messages'].push("Item doesnt belong to current order")
        else
          @order.addactivity("Item instruction scanned for product - #{params[:next_item]['name']}", current_user.username)
        end

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
