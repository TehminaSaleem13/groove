# frozen_string_literal: true

module SettingsHelper
  def zip_to_files(filename, data_object)
    require 'zip'
    temp_file = Tempfile.new(filename)
    begin
      Zip::OutputStream.open(temp_file) { |zos| }
      Zip::File.open(temp_file.path, Zip::File::CREATE) do |zip|
        data_object.each do |ident, file|
          zip.add(ident.to_s + '.csv', file)
        end
      end
      zip_data = File.read(temp_file.path)
    ensure
      temp_file.close
      temp_file.unlink
    end
  end

  def import_orders_helper(tenant)
    Apartment::Tenant.switch!(tenant)
    order_summary = OrderImportSummary.where(
      status: 'in_progress'
    )

    if order_summary.empty?
      order_summary_info = OrderImportSummary.new
      order_summary_info.user_id = nil
      order_summary_info.status = 'not_started'
      order_summary_info.save
      # call delayed job
      import_orders_obj = ImportOrders.new
      # import_orders_obj.delay(:run_at => 1.seconds.from_now,:queue => 'importing orders').import_orders
      import_orders_obj.import_orders(tenant)
      import_orders_obj.reschedule_job('import_orders', tenant)
    end
  end

  def update_bulk_action(bulk_action_id, result)
    bulk_action = GrooveBulkActions.find_by_id(bulk_action_id)
    if bulk_action.present?
      bulk_action.cancel = true
      bulk_action.status = 'cancelled'
      bulk_action.save && result['bulk_action_cancelled_ids']
        .push(bulk_action_id)
      # puts 'We saved the bulk action objects'
      # puts 'Error occurred while saving bulk action object'
    else
      result['error_messages'] = ['No bulk action found with the id.']
    end
    $redis.del("bulk_action_delete_data_#{Apartment::Tenant.current}_#{bulk_action_id}")
    $redis.del("bulk_action_duplicate_data_#{Apartment::Tenant.current}_#{bulk_action_id}")
    $redis.del("bulk_action_data_#{Apartment::Tenant.current}_#{bulk_action_id}")
  end

  def permit_scan_pack_setting_params
    # Add params.permit when upgradng to rails 4
    params.as_json(
      only: %i[
        enable_click_sku ask_tracking_number show_success_image
        show_order_complete_image success_image_time
        order_complete_image_time play_success_sound
        play_order_complete_sound show_fail_image fail_image_time
        play_fail_sound skip_code_enabled skip_code
        note_from_packer_code_enabled note_from_packer_code
        service_issue_code_enabled service_issue_code
        restart_code_enabled restart_code
        type_scan_code_enabled type_scan_code post_scanning_option
        escape_string_enabled escape_string record_lot_number
        show_customer_notes show_internal_notes show_tags
        scan_by_shipping_label intangible_setting_enabled
        intangible_string intangible_setting_gen_barcode_from_sku
        post_scan_pause_enabled post_scan_pause_time
        display_location string_removal_enabled string_removal
        first_escape_string_enabled second_escape_string_enabled
        second_escape_string order_verification scan_by_packing_slip
        pass_scan pass_scan_barcode
        return_to_orders scanning_sequence click_scan click_scan_barcode
        scanned scanned_barcode partial partial_barcode post_scanning_option_second
        require_serial_lot valid_prefixes replace_gp_code single_item_order_complete_msg
        single_item_order_complete_msg_time multi_item_order_complete_msg multi_item_order_complete_msg_time
        tote_identifier show_expanded_shipments tracking_number_validation_enabled
        tracking_number_validation_prefixes scan_by_packing_slip_or_shipping_label remove_enabled
        remove_barcode remove_skipped display_location2 display_location3 camera_option
        packing_option resolution packing_cam_enabled email_customer_option email_subject
        email_insert_dropdown email_message customer_page_dropdown customer_page_message scanning_log
      ]
    )
  end

  def permit_printing_setting_params
    # Add params.permit when upgradng to rails 4
    params.as_json(
      only: [
        :product_barcode_label_size
      ]
    )
  end

  def permit_general_setting_params
    params.as_json(
      only: %i[
        packing_slip_message_to_customer product_weight_format
        packing_slip_size packing_slip_orientation
        conf_req_on_notes_to_packer conf_req_on_notes_to_packer
        strict_cc conf_code_product_instruction
        conf_req_on_notes_to_packer email_address_for_packer_notes
        email_address_for_packer_notes hold_orders_due_to_inventory
        inventory_tracking low_inventory_alert_email
        low_inventory_email_address send_email_for_packer_notes
        default_low_inventory_alert_limit
        email_address_for_billing_notification export_items
        export_items max_time_per_item send_email_on_mon
        send_email_on_tue send_email_on_wed send_email_on_thurs
        send_email_on_fri send_email_on_sat send_email_on_sun
        scheduled_order_import time_to_import_orders
        import_orders_on_mon import_orders_on_tue import_orders_on_wed
        import_orders_on_thurs import_orders_on_fri import_orders_on_sat
        import_orders_on_sun tracking_error_order_not_found
        tracking_error_info_not_found custom_field_one
        custom_field_two export_csv_email html_print
        show_primary_bin_loc_in_barcodeslip time_to_send_email schedule_import_mode master_switch
        idle_timeout hex_barcode from_import to_import multi_box_shipments per_box_packing_slips
        custom_user_field_one custom_user_field_two display_kit_parts remove_order_items create_barcode_at_import
        print_post_scanning_barcodes print_packing_slips print_ss_shipping_labels per_box_shipping_label_creation
        barcode_length starting_value show_sku_in_barcodeslip print_product_barcode_labels new_time_zone
      ]
    )
  end

  def send_csv_data(result)
    respond_to do |format|
      format.csv do
        send_data result['data'], type: 'text/csv',
                                  filename: result['filename'],
                                  nothing: true
      end
    end
  end

  def update_scan_pack_settings_attributes(scan_pack_setting)
    if current_user.can? 'edit_scanning_prefs'
      params[:tote_identifier] = params[:tote_identifier].present? ? params[:tote_identifier] : 'Tote'

      if scan_pack_setting.update_attributes(permit_scan_pack_setting_params)
        update_tote_sets if params[:tote_sets]
        @result['success_messages'] = ['Settings updated successfully.']
      else
        @result['status'] &= false
        @result['error_messages'] = ['Error saving Scan Pack settings.']
      end
    else
      @result['status'] &= false
      @result['error_messages'] = ['You are not authorized to update scan pack preferences.']
    end
  end

  def bin_location(product)
    product.product_inventory_warehousess.first.location_primary
  rescue StandardError
    nil
  end

  def update_tote_sets
    params[:tote_sets].each do |set|
      tote_set = ToteSet.find_by_id(params[:id])
      next unless tote_set.present?

      tote_set.update_attributes(max_totes: set[:max_totes])
      if tote_set.totes.count > tote_set.max_totes
        (tote_set.totes.order('number ASC').all - tote_set.totes.order('number ASC').first(tote_set.max_totes)).each(&:destroy)
      elsif tote_set.totes.count < tote_set.max_totes
        Range.new(1, (tote_set.max_totes - tote_set.totes.count)).to_a.each do
          tote_set.totes.create(name: "T-#{Tote.all.count + 1}", number: Tote.all.count + 1)
        end
      end
    end
  end

  def update_with_stripe_customer(customer)
    if customer.try(:stripe_customer_id).present?
      stripe_customer = Stripe::Customer.retrieve(customer.stripe_customer_id)
      stripe_customer.email = params['email_address_for_billing_notification']
      if begin
            params['email_address_for_billing_notification'].include?('@')
         rescue StandardError
           false
          end
        begin
          stripe_customer.save
          general_setting = GeneralSetting.all.first
          general_setting.email_address_for_billing_notification = stripe_customer.email
          general_setting.save
        rescue StandardError
          @result['status'] &= false
          @result['error_messages'] = ['No customer found']
        end
      else
        @result['status'] &= false
        @result['error_messages'] = ['Please update correct email address']
      end
    else
      @result['status'] &= false
      @result['error_messages'] = ['Not having valid stripe customer id']
    end
    @result
  end

  def upadate_setting_attributes(general_setting, current_user, printing_setting = nil)
    if general_setting.present?
      if current_user.can? 'edit_general_prefs'
        general_setting.attributes = permit_general_setting_params
        printing_setting.attributes = permit_printing_setting_params

        if general_setting.save &&  printing_setting.save
          @result['success_messages'] = ['Settings updated successfully.']
        else
          @result['status'] &= false
          @result['error_messages'] = ['Error saving general settings.']
        end
      else
        @result['status'] &= false
        @result['error_messages'] = ['You are not authorized to update general preferences.']
      end
    else
      @result['status'] &= false
      @result['error_messages'] = ['No general settings available for the system. Contact administrator.']
    end
    @result
  end
end
