class ScanPackController < ApplicationController
  before_filter :groovepacker_authorize!
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
      'scanpack.rfp.recording' => ['scan_recording'],
      'scanpack.rfp.verifying' => ['scan_verifying'],
      'scanpack.rfp.no_tracking_info' => ['render_order_scan'],
      'scanpack.rfp.no_match' => ['scan_again_or_render_order_scan'],
      'scanpack.rfp.product_edit' => ['order_scan'],
      'scanpack.rfp.product_edit.single' => ['order_scan'],
      'scanpack.rfp.confirmation.product_edit' => ['product_edit_conf', 'order_scan'],
      'scanpack.rfp.confirmation.order_edit' => ['order_edit_conf', 'order_scan'],
      'scanpack.rfp.confirmation.cos' => ['cos_conf', 'order_scan']
    }

    if params[:state].nil?
      @result['status'] &= false
      @result['error_messages'].push("Please specify a state")
    else

      @matcher[params[:state]].each do |state_func|
        output = send(state_func, params[:input], params[:state], params[:id])
        @result['error_messages'] = @result['error_messages'] + output['error_messages']
        @result['success_messages'] = @result['success_messages'] + output['success_messages']
        @result['notice_messages'] = @result['notice_messages'] + output['notice_messages']
        @result['status'] = output['status']
        @result['data'] = output['data']
        @result['matched'] = output['matched']
        break if output["matched"]
      end
    end

    if params[:state] == "scanpack.rfp.default" && @result['status'] == true
      Order.find(params[:id]).addactivity("Product with barcode: " + params[:input].to_s + " scanned", current_user.name)
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
        @result['error_messages'].push("Order with id: "+params[:order_id].to_s+" is already in scanned state")
      end
    else
      @result['status'] &= false
      @result['error_messages'].push("Could not find order with id: "+params[:order_id].to_s)
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end

  def serial_scan
    @result = Hash.new
    @result['status'] = true
    @result['error_messages'] = []
    @result['success_messages'] = []
    @result['notice_messages'] = []

    serial_added = true
    if params[:serial].blank?
      params[:serial] = 'N/A'
      serial_added = false
    end

    if params[:order_id].nil? || params[:product_id].nil?
      @result['status'] = false
      @result['error_messages'].push('Order id and Product id are required')
    else
      order = Order.find(params[:order_id])
      product = Product.find(params[:product_id])

      if order.nil?
        @result['status'] &= false
        @result['error_messages'].push('Could not find order with id: '+params[:order_id].to_s)
      elsif product.nil?
        @result['status'] &= false
        @result['error_messages'].push('Could not find product with id: '+params[:product_id].to_s)
      else
        if barcode_found_or_special_code(params[:serial])
          @result['status'] &= false
          @result['error_messages'].push('Product Serial number: "'+params[:serial].to_s+'" can not be the same as a confirmation code, one of the action codes or any product barcode')
        else
          order_serials = OrderSerial.where(order_id: order.id, product_id: product.id, serial: params[:serial])
          unless order_serials.empty?
            order_serial = order_serials.first
          else
            order_serial = OrderSerial.new
            order_serial.order = order
            order_serial.product = product
            order_serial.serial = params[:serial]
            order_serial.save
          end

          if params[:product_lot_id].nil?
            order_item_serial_lots = OrderItemOrderSerialProductLot.where(order_item_id: params[:order_item_id], product_lot_id: params[:product_lot_id], order_serial_id: order_serial.id)
            if order_item_serial_lots.empty?
              OrderItemOrderSerialProductLot.create(order_item_id: params[:order_item_id], product_lot_id: params[:product_lot_id], order_serial_id: order_serial.id, qty: 1)
            else
              existing_serial = order_item_serial_lots.first
              existing_serial.qty += 1
              existing_serial.save
            end
          else
            order_item_serial_lots = OrderItemOrderSerialProductLot.where(order_item_id: params[:order_item_id], product_lot_id: params[:product_lot_id])
            unless order_item_serial_lots.empty?
              existing_serials = order_item_serial_lots.where(order_serial_id: order_serial.id)
              if existing_serials.empty?
                new_serial = order_item_serial_lots.where(order_serial_id: nil).first
                new_serial.order_serial = order_serial
                new_serial.save
              else
                order_item_serial_lots.where(order_serial_id: nil).first.destroy
                existing_serial = existing_serials.first
                existing_serial.qty += 1
                existing_serial.save
              end
            end
          end
          @result = product_scan(params[:barcode], 'scanpack.rfp.default', params[:order_id], params[:clicked], serial_added)
          order.addactivity('Product: "'+product.name.to_s+'" Serial scanned: "'+params[:serial].to_s+'"', current_user.name)
        end
      end
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
      @order = Order.where(id: params[:id]).first
      if @order.nil?
        @result['status'] &= false
        @result['error_messages'].push('Could not find order with id: '+params[:id].to_s)
      else
        @order.notes_fromPacker = params[:note].to_s
        general_settings = GeneralSetting.all.first
        email_present = general_settings.email_address_for_packer_notes.present?
        if @order.save && email_present
          @result['success_messages'].push('Note from Packer saved successfully')
          if general_settings.send_email_for_packer_notes == 'always' ||
            (general_settings.send_email_for_packer_notes == 'optional' && email)
            #send email
            mail_settings = Hash.new
            mail_settings['email'] = general_settings.email_address_for_packer_notes
            mail_settings['sender'] = current_user.name + ' ('+current_user.username+')'
            mail_settings['tenant_name'] = Apartment::Tenant.current
            mail_settings['order_number'] = @order.increment_id
            mail_settings['order_id'] = @order.id
            mail_settings['note_from_packer'] = @order.notes_fromPacker

            NotesFromPacker.send_email(mail_settings).deliver
          end
        else
          @result['status'] &= false
          msg = if email_present
            'There was an error saving note from packer, please try again'
          else
            'Email not found for notification settings.'
          end
          @result['error_messages'].push(msg)
        end
      end
    end
    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end

  end

  def order_instruction
    # @result = Hash.new
    # @result['status'] = true
    # @result['error_messages'] = []
    # @result['success_messages'] = []
    # @result['notice_messages'] = []
    # @result['data'] = Hash.new

    # if params[:id].nil? || params[:code].nil?
    #   @result['status'] &= false
    #   @result['error_messages'].push('Order id and confirmation code required')
    # else
    #   general_setting = GeneralSetting.all.first
    #   @order = Order.find(params[:id])
    #   if @order.nil?
    #     @result['status'] &= false
    #     @result['error_messages'].push('Could not find order with id: '+params[:id].to_s)
    #   elsif !general_setting.strict_cc || current_user.confirmation_code == params[:code]
    #     @order.addactivity('Order instructions confirmed', current_user.username)
    #   else
    #     @result['status'] &= false
    #     @result['error_messages'].push('Confirmation code doesn\'t match')
    #   end
    # end

    # respond_to do |format|
    #   format.html # show.html.erb
    #   format.json { render json: @result }
    # end
  end

  def click_scan
    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: product_scan(params[:barcode], 'scanpack.rfp.default', params[:id], true) }
    end
  end

  def confirmation_code
    general_setting = GeneralSetting.all.first
    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: {confirmed: (!general_setting.strict_cc || current_user.confirmation_code == params[:code])} }
    end
  end

  def type_scan
    @result = Hash.new
    @result['status'] = true
    @result['error_messages'] = []
    @result['success_messages'] = []
    @result['notice_messages'] = []
    @result['data'] = Hash.new
    if params[:id].nil? || params[:count].to_i < 1 || params[:next_item].nil?
      @result['status'] &= false
      @result['error_messages'].push('Order id, Item id and Type-in count are required')
    else
      @order = Order.find(params[:id])
      if @order.nil?
        @result['status'] &= false
        @result['error_messages'].push('Could not find order with id: '+params[:id].to_s)
      else
        @order_item = OrderItem.find(params[:next_item]['order_item_id'])
        unless params[:next_item]['kit_product_id'].nil?
          @order_kit_product = OrderItemKitProduct.find(params[:next_item]['kit_product_id'])
        end
        if @order_item.nil?
          @result['status'] &= false
          @result['error_messages'].push('Couldnt find order item')
        elsif !params[:next_item]['kit_product_id'].nil? && (@order_kit_product.nil? ||
          @order_kit_product.order_item_id != @order_item.id)
          @result['status'] &= false
          @result['error_messages'].push('Couldnt find child item')
        elsif @order_item.order_id != @order.id
          @result['status'] &= false
          @result['error_messages'].push('Item doesnt belong to current order')
        else
          if params[:count] <= params[:next_item][:qty]
            unless params[:next_item][:barcodes].blank? || params[:next_item][:barcodes][0].blank? || params[:next_item][:barcodes][0][:barcode].blank?
              @result['data'] = product_scan(params[:next_item][:barcodes][0][:barcode], 'scanpack.rfp.default', params[:id], false, false, params[:count].to_i)
              @order.addactivity('Type-In count Scanned for product'+params[:next_item][:sku].to_s, current_user.username)
            end
          else
            @result['status'] &= false
            @result['error_messages'].push('Wrong count has been entered. Please try again')
          end
        end
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

    if params[:id].nil? || params[:code].nil? || params[:next_item].nil?
      @result['status'] &= false
      @result['error_messages'].push('Order id, Item id and confirmation code required')
    else
      @order = Order.where(id: params[:id]).first
      general_setting = GeneralSetting.all.first

      if @order.nil?
        @result['status'] &= false
        @result['error_messages'].push('Could not find order with id: '+params[:id].to_s)
      elsif !general_setting.strict_cc || current_user.confirmation_code == params[:code]
        @order_item = OrderItem.where(id: params[:next_item]['order_item_id']).first
        unless params[:next_item]['kit_product_id'].nil?
          @order_kit_product = OrderItemKitProduct.where(id: params[:next_item]['kit_product_id']).first
        end
        if @order_item.nil?
          @result['status'] &= false
          @result['error_messages'].push('Couldnt find order item')
        elsif !params[:next_item]['kit_product_id'].nil? && (@order_kit_product.nil? ||
          @order_kit_product.order_item_id != @order_item.id)
          @result['status'] &= false
          @result['error_messages'].push('Couldnt find child item')
        elsif @order_item.order_id != @order.id
          @result['status'] &= false
          @result['error_messages'].push('Item doesnt belong to current order')
        else
          @order.addactivity("Item instruction scanned for product - #{params[:next_item]['name']}", current_user.username)
        end

      else
        @result['status'] &= false
        @result['error_messages'].push('Confirmation code doesn\'t match')
      end
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end
end
