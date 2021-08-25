module Expo
    class NewAddNoteService < ScanPack::Base
      def initialize(current_user, session, params)
        set_scan_pack_action_instances(current_user, session, params)
        @order = Order.where(id: @params[:id]).first
        @general_settings = GeneralSetting.first
      end
  
      def run
        add_note
        @result
      end

      def add_note
        @order.notes_fromPacker = @params[:note].to_s
        email_present = @general_settings.email_address_for_packer_notes.present?
        if @order.save && email_present
          do_if_order_and_email_present
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
