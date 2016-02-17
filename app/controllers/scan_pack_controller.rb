class ScanPackController < ApplicationController
  before_filter :groovepacker_authorize!, :set_result_instance
  include ScanPackHelper

  def set_result_instance
    @result = {
      "status" => true, "error_messages" => [], "success_messages" => [],
      "notice_messages" => [], 'data' => {}
    }
  end

  def scan_barcode
    @result = do_scan_barcode
    render json: @result
  end

  # takes order_id as input and resets scan status if it is partially scanned.
  def reset_order_scan
    @order = Order.where(id: params[:order_id]).first

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

    render json: @result
  end

  def serial_scan
    @result = do_serial_scan
    render json: @result
  end

  def add_note
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
    
    render json: @result
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

    # render json: @result
  end

  def click_scan
    render json: product_scan(
        params[:barcode], 'scanpack.rfp.default', params[:id],
        {
          clicked: true, current_user: current_user, session: session
        }
      )
  end

  def confirmation_code
    general_setting = GeneralSetting.all.first
    render json: {confirmed: (!general_setting.strict_cc || current_user.confirmation_code == params[:code])}
  end

  def type_scan

    if params[:id].nil? || params[:count].to_i < 1 || params[:next_item].nil?
      @result['status'] &= false
      @result['error_messages'].push('Order id, Item id and Type-in count are required')
    else
      @order = Order.where(id: params[:id]).first
      if @order.nil?
        @result['status'] &= false
        @result['error_messages'].push('Could not find order with id: '+params[:id].to_s)
      else
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
          if params[:count] <= params[:next_item][:qty]
            unless params[:next_item][:barcodes].blank? || params[:next_item][:barcodes][0].blank? || params[:next_item][:barcodes][0][:barcode].blank?
              @result['data'] = product_scan(
                  params[:next_item][:barcodes][0][:barcode], 'scanpack.rfp.default', params[:id],
                  { 
                    clicked: false, serial_added: false, typein_count: params[:count].to_i,
                    current_user: current_user, session: session
                  }
                )
              @order.addactivity('Type-In count Scanned for product'+params[:next_item][:sku].to_s, current_user.username)
            end
          else
            @result['status'] &= false
            @result['error_messages'].push('Wrong count has been entered. Please try again')
          end
        end
      end

    end
    
    render json: @result

  end

  def product_instruction

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

    render json: @result

  end
end
