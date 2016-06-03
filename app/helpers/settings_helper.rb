module SettingsHelper
  def zip_to_files(filename, data_object)
    require 'zip'
    temp_file = Tempfile.new(filename)
    begin
      Zip::OutputStream.open(temp_file) { |zos|}
      Zip::File.open(temp_file.path, Zip::File::CREATE) do |zip|
        data_object.each do |ident, file|
          zip.add(ident.to_s+".csv", file)
        end
      end
      zip_data = File.read(temp_file.path)
    ensure
      temp_file.close
      temp_file.unlink
    end
  end

  def import_orders_helper(tenant)
    Apartment::Tenant.switch(tenant)
    order_summary = OrderImportSummary.where(
      status: 'in_progress')

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
  end

  def permit_scan_pack_setting_params
    # Add params.permit when upgradng to rails 4
    params.as_json(
      only: [
        :enable_click_sku, :ask_tracking_number, :show_success_image,
        :show_order_complete_image, :success_image_time,
        :order_complete_image_time, :play_success_sound,
        :play_order_complete_sound, :show_fail_image, :fail_image_time,
        :play_fail_sound, :skip_code_enabled, :skip_code,
        :note_from_packer_code_enabled, :note_from_packer_code,
        :service_issue_code_enabled, :service_issue_code,
        :restart_code_enabled, :restart_code,
        :type_scan_code_enabled, :type_scan_code, :post_scanning_option,
        :escape_string_enabled, :escape_string, :record_lot_number,
        :show_customer_notes, :show_internal_notes,
        :scan_by_tracking_number, :intangible_setting_enabled,
        :intangible_string, :intangible_setting_gen_barcode_from_sku,
        :post_scan_pause_enabled, :post_scan_pause_time
      ]
    )
  end

  def permit_general_setting_params
    params.as_json(
      only: [
        :packing_slip_message_to_customer, :product_weight_format,
        :packing_slip_size, :packing_slip_orientation,
        :conf_req_on_notes_to_packer, :conf_req_on_notes_to_packer,
        :strict_cc, :conf_code_product_instruction,
        :conf_req_on_notes_to_packer, :email_address_for_packer_notes,
        :email_address_for_packer_notes, :hold_orders_due_to_inventory,
        :inventory_tracking, :low_inventory_alert_email,
        :low_inventory_email_address, :send_email_for_packer_notes,
        :default_low_inventory_alert_limit,
        :default_low_inventory_alert_limit, :export_items,
        :export_items, :max_time_per_item, :send_email_on_mon,
        :send_email_on_tue, :send_email_on_wed, :send_email_on_thurs,
        :send_email_on_fri, :send_email_on_sat, :send_email_on_sun,
        :scheduled_order_import, :time_to_import_orders,
        :import_orders_on_mon, :import_orders_on_tue, :import_orders_on_wed,
        :import_orders_on_thurs, :import_orders_on_fri, :import_orders_on_sat,
        :import_orders_on_sun, :tracking_error_order_not_found,
        :tracking_error_info_not_found, :custom_field_one,
        :custom_field_two, :export_csv_email,
        :show_primary_bin_loc_in_barcodeslip
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
      if scan_pack_setting.update_attributes(permit_scan_pack_setting_params)
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
    product.product_inventory_warehousess.first.location_primary rescue nil
  end
end
