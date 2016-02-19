module ScanPack
  class AddNoteService < ScanPack::Base
    def initialize(current_user, session, params)
      set_scan_pack_action_instances(current_user, session, params)
      @order = Order.where(id: @params[:id]).first
      @general_settings = GeneralSetting.all.first
    end
    
    def run
      add_note if data_and_params_valid
      @result
    end

    def data_and_params_valid
      if @params[:id].blank? || @params[:note].blank?
        set_error_messages('Order id and note from packer required')
      elsif @order.blank?
        set_error_messages("Could not find order with id: #{@params[:id].to_s}")
      end
      @result['status']
    end

    def add_note
      @order.notes_fromPacker = @params[:note].to_s
      email_present = @general_settings.email_address_for_packer_notes.present?
      if @order.save && email_present
        do_if_order_and_email_present
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

    def do_if_order_and_email_present
      @result['success_messages'].push('Note from Packer saved successfully')
      if @general_settings.send_email_for_packer_notes == 'always' ||
        (@general_settings.send_email_for_packer_notes == 'optional' && @params[:email])
        #send email
        mail_settings = {
          "email" => @general_settings.email_address_for_packer_notes,
          "sender" => "#{@current_user.name} (#{@current_user.username})",
          "tenant_name" => Apartment::Tenant.current,
          "order_number" => @order.increment_id,
          "order_id" => @order.id,
          "note_from_packer" => @order.notes_fromPacker
        }
        NotesFromPacker.send_email(mail_settings).deliver
      end
    end

  end
end