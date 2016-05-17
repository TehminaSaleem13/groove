class SettingsController < ApplicationController
  before_filter :groovepacker_authorize!
  include SettingsHelper

  def restore
    @result = SettingsService::Restore.call(
      current_user: current_user,
      params: params
    ).result
    respond_to do |format|
      format.json { render json: @result }
    end
  end

  def export_csv
    puts 'export_csv'
    @result = {}
    @result['status'] = true
    @result['messages'] = []
    if current_user.can?('create_backups')
      GrooveBulkActions.execute_groove_bulk_action('export', params, current_user)
    else
      @result['status'] = false
      @result['messages'].push('You do not have enough permissions to backup and restore')
    end
    # if current_user.can? 'create_backups'
    #   dir = Dir.mktmpdir([current_user.username+'groov-export-', Time.now.to_s])
    #   filename = 'groove-export-'+Time.now.to_s+'.zip'
    #   begin
    #     data = zip_to_files(filename, Product.to_csv(dir))

    #   ensure
    #     FileUtils.remove_entry_secure dir
    #   end
    # else
    #   #prevent a fail and send empty zip
    #   filename = 'insufficient_permissions.zip'
    #   data = zip_to_files(filename, {})
    # end
    puts '@result: ' + @result.inspect

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end

  def order_exceptions
    result = SettingsService::OrderExceptionService.call(
      current_user: current_user, params: params
    ).result

    respond_to do |format|
      format.csv do
        send_data result['data'], type: 'text/csv',
                                  filename: result['filename'],
                                  nothing: true
      end
    end
  end

  def order_serials
    require 'csv'
    result = {}
    result['status'] = true
    result['messages'] = []
    if current_user.can? 'view_packing_ex'
      if params[:start].nil? || params[:end].nil?
        result['status'] = false
        result['messages'].push('We need a start and an end time')
      else
        serials = OrderSerial.where(updated_at: Time.parse(params[:start])..Time.parse(params[:end]))
        filename = 'groove-order-serials-' + Time.now.to_s + '.csv'
        row_map = {
          order_date: '',
          order_number: '',
          serial: '',
          primary_sku: '',
          primary_barcode: '',
          product_name: '',
          item_sale_price: '',
          kit_name: '',
          scan_order: 0,
          customer_name: '',
          address1: '',
          address2: '',
          city: '',
          state: '',
          zip: '',
          packing_user: '',
          order_item_count: '',
          scanned_date: '',
          warehouse_name: ''
        }
        data = CSV.generate do |csv|
          csv << row_map.keys
          order_number = ''
          scan_order = 0
          serials.each do |serial|
            single_row = row_map.dup
            if order_number == serial.order.increment_id
              scan_order += 1
            else
              order_number = serial.order.increment_id
              scan_order = 1
            end
            single_row[:scan_order] = scan_order
            single_row[:order_number] = serial.order.increment_id
            single_row[:order_date] = serial.order.order_placed_time
            single_row[:scanned_date] = serial.order.scanned_on
            packing_user = nil
            packing_user = User.find(serial.order.packing_user_id) unless serial.order.packing_user_id.blank?
            unless packing_user.nil?
              single_row[:packing_user] = packing_user.name + ' (' + packing_user.username + ')'
              single_row[:warehouse_name] = serial.product.primary_warehouse.inventory_warehouse.name unless serial.product.primary_warehouse.nil? || serial.product.primary_warehouse.inventory_warehouse.nil?
            end
            single_row[:serial] = serial.serial
            if serial.product.is_kit == 1
              single_row[:kit_name] = serial.product.name
            else
              single_row[:product_name] = serial.product.name
            end
            single_row[:customer_name] = [serial.order.firstname, serial.order.lastname].join(' ')
            single_row[:address1] = serial.order.address_1
            single_row[:address2] = serial.order.address_2
            single_row[:city] = serial.order.city
            single_row[:state] = serial.order.state
            single_row[:zip] = serial.order.postcode
            single_row[:primary_sku] = serial.product.primary_sku
            single_row[:primary_barcode] = serial.product.primary_barcode
            single_row[:order_item_count] = serial.order.get_items_count
            # item sale price
            order_items = serial.order.order_items.where(product_id: serial.product.id)
            if order_items.empty?
              single_row[:item_sale_price] = ''
            else
              single_row[:item_sale_price] = order_items.first.price
            end
            csv << single_row.values
          end
        end

      end
    else
      result['status'] = false
      result['messages'].push('You do not have enough permissions to view order serials')
    end

    unless result['status']
      data = CSV.generate do |csv|
        csv << result['messages']
      end
      filename = 'error.csv'
    end

    respond_to do |format|
      format.html # show.html.erb
      format.csv { send_data data, type: 'text/csv', filename: filename }
    end
  end

  def get_columns_state
    @result = {}
    @result['status'] = true
    @result['messages'] = []
    if params[:identifier].nil?
      @result['messages'].push('No Identifier for state preference given')
      @result['status'] = false
    else
      preference = ColumnPreference.find_by_user_id_and_identifier(current_user.id, params[:identifier])
      @result['data'] = preference unless preference.nil?
    end
    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end

  def save_columns_state
    @result = {}
    @result['status'] = true
    @result['messages'] = []
    if params[:identifier].nil?
      @result['messages'].push('No Identifier for state preference given')
      @result['status'] = false
    else
      preference = ColumnPreference.find_or_create_by_user_id_and_identifier(current_user.id, params[:identifier])
      preference.theads = params[:theads]
      preference.save!
    end
    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end

  def get_settings
    @result = {}
    @result['status'] = true
    @result['error_messages'] = []
    @result['success_messages'] = []
    @result['notice_messages'] = []
    @result['data'] = {}

    general_setting = GeneralSetting.all.first

    if general_setting.present?
      @result['data']['settings'] = general_setting
    else
      @result['status'] &= false
      @result['error_messages'].push(
        'No general settings available for the system. Contact administrator.'
      )
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end

  def update_settings
    @result = {}
    @result['status'] = true
    @result['error_messages'] = []
    @result['success_messages'] = []
    @result['notice_messages'] = []

    general_setting = GeneralSetting.all.first

    if !general_setting.nil?
      if current_user.can? 'edit_general_prefs'
        general_setting.attributes = permit_general_setting_params
        if general_setting.save
          @result['success_messages'].push('Settings updated successfully.')
        else
          @result['status'] &= false
          @result['error_messages'].push('Error saving general settings.')
        end
      else
        @result['status'] &= false
        @result['error_messages'].push('You are not authorized to update general preferences.')
      end
    else
      @result['status'] &= false
      @result['error_messages'].push('No general settings available for the system. Contact administrator.')
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end

  def cancel_bulk_action
    result = {
      'status' => true, 'success_messages' => [],
      'notice_messages' => [], 'error_messages' => [],
      'bulk_action_cancelled_ids' => []
    }

    if params[:id].nil?
      result['status'] = false
      result['error_messages'].push('no id bulk action id provided')
    else
      params[:id].each do |bulk_action_id|
        bulk_action = GrooveBulkActions.find_by_id(bulk_action_id)
        if bulk_action.nil?
          result['error_messages'].push('No bulk action found with the id.')
        else
          bulk_action.cancel = true
          bulk_action.status = 'cancelled'
          if bulk_action.save
            result['bulk_action_cancelled_ids'].push(bulk_action_id)
            puts 'We saved the bulk action objects'
          else
            puts 'Error occurred while saving bulk action object'
          end
        end
      end
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: result }
    end
  end

  def get_scan_pack_settings
    @result = {}
    @result['status'] = true
    @result['error_messages'] = []
    @result['success_messages'] = []
    @result['notice_messages'] = []
    @result['settings'] = {}

    scan_pack_setting = ScanPackSetting.all.first

    if !scan_pack_setting.nil?
      @result['settings'] = scan_pack_setting
    else
      @result['status'] &= false
      @result['error_messages'].push('No Scan Pack settings available for the system. Contact administrator.')
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end

  def print_action_barcode
    scan_pack_setting = ScanPackSetting.all.first
    @action_code = scan_pack_setting[params[:id]]

    respond_to do |format|
      format.html
      format.pdf do
        render pdf: 'action_barcode_' + params[:id].to_s,
               template: 'settings/action_barcodes.html.erb',
               orientation: 'Portrait',
               page_height: '1in',
               page_width: '3in',
               margin: {
                 top: '0',
                 bottom: '0',
                 left: '0',
                 right: '0'
               }
      end
    end
  end

  def update_scan_pack_settings
    @result = {
      'status' => true,
      'error_messages' => [],
      'success_messages' => [],
      'notice_messages' => []
    }

    scan_pack_setting = ScanPackSetting.all.first

    if !scan_pack_setting.nil?
      if current_user.can? 'edit_scanning_prefs'
        if scan_pack_setting.update_attributes(permit_scan_pack_setting_params)
          @result['success_messages'].push('Settings updated successfully.')
        else
          @result['status'] &= false
          @result['error_messages'].push('Error saving Scan Pack settings.')
        end
      else
        @result['status'] &= false
        @result['error_messages'].push('You are not authorized to update scan pack preferences.')
      end
    else
      @result['status'] &= false
      @result['error_messages'].push('No Scan pack settings available for the system. Contact administrator.')
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end

  def send_test_mail
    LowInventoryLevel.notify(GeneralSetting.all.first, Apartment::Tenant.current).deliver
    render json: 'ok'
  end

  def execute_in_bulk_action(activity)
    result = {}
    result['status'] = true
    result['messages'] = []
    if current_user.can?('create_backups')
      GrooveBulkActions.execute_groove_bulk_action(activity, params, current_user)
    else
      result['status'] = false
      result['messages'].push('You do not have enough permissions to backup and restore')
    end
    result
    # respond_to do |format|
    #   format.html # show.html.erb
    #   format.json { render json: result }
    # end
  end

  private

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
        :custom_field_two, :export_csv_email
      ]
    )
  end
end
