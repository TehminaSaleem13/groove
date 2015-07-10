class SettingsController < ApplicationController
  before_filter :groovepacker_authorize!
  include SettingsHelper
  def restore
    @result = Hash.new
    @result['status'] = true
    @result['messages'] = []
    if current_user.can? 'restore_backups'
        # Every entry on mapping[current_mapping][:map] should be in the format
      # csv_header => db_table_header
      if params[:method] == 'del_import_old'
        product_map = {
                  'id' => 'id',
                  'store_product_id' => 'store_product_id',
                  'name' => 'name',
                  'product_type' => 'product_type',
                  'store_id' => 'store_id',
                  'created_at' => 'created_at',
                  'updated_at' => 'updated_at',
                  'inv_wh1' => 'inv_wh1',
                  'status' => 'status',
                  'spl_instructions_4_packer' => 'spl_instructions_4_packer',
                  'spl_instructions_4_confirmation' => 'spl_instructions_4_confirmation',
                  'barcode' => 'barcode',
                  'is_skippable' => 'is_skippable',
                  'packing_placement' => 'packing_placement',
                  'pack_time_adj' => 'pack_time_adj',
                  'kit_parsing' => 'kit_parsing',
                  'is_kit' => 'is_kit',
                  'disable_conf_req' => 'disable_conf_req',
                  'total_avail_ext' =>'total_avail_ext',
                  'weight' =>'weight',
                  'shipping_weight'=>'shipping_weight'
              }
        default_warehouse_map = {
                  'default_wh_avbl' => 'available_inv',
                  'default_wh_loc_primary' =>'location_primary',
                  'default_wh_loc_secondary' => 'location_secondary'
              }
      else
        product_map = {
                  'ID' => 'id',
                  'Name' => 'name',
                  'store_product_id' => 'store_product_id',
                  'product_type' => 'product_type',
                  'store_id' => 'store_id',
                  'created_at' => 'created_at',
                  'updated_at' => 'updated_at',
                  'BinLocation 1' => 'inv_wh1',
                  'status' => 'status',
                  'spl_instructions_4_packer' => 'spl_instructions_4_packer',
                  'spl_instructions_4_confirmation' => 'spl_instructions_4_confirmation',
                  'Barcode 1' => 'barcode',
                  'is_skippable' => 'is_skippable',
                  'packing_placement' => 'packing_placement',
                  'pack_time_adj' => 'pack_time_adj',
                  'kit_parsing' => 'kit_parsing',
                  'is_kit' => 'is_kit',
                  'disable_conf_req' => 'disable_conf_req',
                  'total_avail_ext' =>'total_avail_ext',
                  'Weight' =>'weight',
                  'shipping_weight'=>'shipping_weight'
              }
        default_warehouse_map = {
                  'Quantity Avbl' => 'available_inv',
                  'BinLocation 1' =>'location_primary',
                  'BinLocation 2' => 'location_secondary'
              }
      end
      mapping = {
          'products' => {
              model: Product,
              map: product_map
          },

          'product_barcodes' => {
              model: ProductBarcode,
              map: {
                  'id' => 'id',
                  'product_id' => 'product_id',
                  'barcode' =>'barcode',
                  'created_at' => 'created_at',
                  'updated_at' => 'updated_at',
                  'order' => 'order'
              }
          },
          'product_images' => {
              model: ProductImage,
              map: {
                  'id' => 'id',
                  'product_id' => 'product_id',
                  'image' =>'image',
                  'caption' =>'caption',
                  'created_at' => 'created_at',
                  'updated_at' => 'updated_at',
                  'order' => 'order'
              }
          },
          'product_skus' => {
              model: ProductSku,
              map: {
                  'id' => 'id',
                  'product_id' => 'product_id',
                  'sku' => 'sku',
                  'purpose' => 'purpose',
                  'created_at' => 'created_at',
                  'updated_at' => 'updated_at',
                  'order' => 'order'
              }
          },
          'product_cats' => {
              model: ProductCat,
              map: {
                  'id' => 'id',
                  'category'=> 'category',
                  'product_id' => 'product_id',
                  'created_at' => 'created_at',
                  'updated_at' => 'updated_at'
              }
          },
          'product_kit_skus' => {
              model:ProductKitSkus,
              map: {
                  'id' => 'id',
                  'option_product_id'=> 'option_product_id',
                  'qty'=> 'qty',
                  'product_id' => 'product_id',
                  'created_at' => 'created_at',
                  'updated_at' => 'updated_at',
                  'packing_order' => 'packing_order'
              }
          },
          'product_inventory_warehouses' => {
              model: ProductInventoryWarehouses,
              map: {
                  'id' => 'id',
                  'location'=> 'location',
                  'qty'=> 'qty',
                  'product_id' => 'product_id',
                  'created_at' => 'created_at',
                  'updated_at' => 'updated_at',
                  'alert' =>'alert',
                  'location_primary' => 'location_primary',
                  'location_secondary' => 'location_secondary',
                  'name'=> 'name',
                  'inventory_warehouse_id' => 'inventory_warehouse_id',
                  'available_inv' => 'available_inv',
                  'allocated_inv' =>'allocated_inv'
              }
          }
      }

      if params[:method].nil? || !['del_import_old','del_import_new'].include?(params[:method])
        @result['status'] = false
        @result.messages.push("No action selected")
      elsif params[:file].nil?
        @result['status'] = false
        @result.messages.push("No file selected")
      else
        require 'zip'
        require 'csv'
        # Clear tables if delete method is invoked
        mapping.each do |single_map|
          single_map[1][:model].delete_all
        end

        products_to_check_later = []
        # Open uploaded zip file
        Zip::File.open(params[:file].path) do |zipfile|
          # For each csv in the zip
          zipfile.each do |file|
            # Remove .csv extension to check if we have mapping defined for it
            current_mapping = file.name.chomp(".csv")
            if mapping.key?(current_mapping)
              # Parse the file by it's data
              CSV.parse(zipfile.read(file.name),:headers=> true) do |csv_row|
                single_row = nil
                create_new = false
                # Create new row if deleted all else find and select by id for updating
                # if params[:method] == 'del_import'
                if current_mapping == 'product_barcodes'
                  all_rows = mapping[current_mapping][:model].where(:barcode =>csv_row['barcode'].strip,:product_id=>csv_row['product_id'])
                  if all_rows.length >0
                    single_row = all_rows.first
                  end
                elsif current_mapping == 'product_skus'
                  all_rows = mapping[current_mapping][:model].where(:sku =>csv_row['sku'].strip,:product_id=>csv_row['product_id'])
                  if all_rows.length >0
                    single_row = all_rows.first
                  end
                elsif current_mapping == 'product_cats'
                  all_rows = mapping[current_mapping][:model].where(:category =>csv_row['category'].strip,:product_id=>csv_row['product_id'])
                  if all_rows.length >0
                    single_row = all_rows.first
                  end
                elsif current_mapping == 'product_images'
                  all_rows = mapping[current_mapping][:model].where(:image =>csv_row['image'],:product_id=>csv_row['product_id'])
                  if all_rows.length > 0
                    single_row = all_rows.first
                  end
                elsif current_mapping == 'product_inventory_warehouses'
                  all_rows = mapping[current_mapping][:model].where(:inventory_warehouse_id =>csv_row['inventory_warehouse_id'],:product_id=>csv_row['product_id'])
                  if all_rows.length > 0
                    single_row = all_rows.first
                  end
                end
                if single_row.nil?
                  single_row = mapping[current_mapping][:model].new
                  create_new = true
                end

                unless single_row.nil?
                  # Now loop through all our defined mappings to check and update values
                  mapping[current_mapping][:map].each do |column|
                    if current_mapping=='product_skus' && column[1] =='id' && !create_new
                      break;
                    end
                    # If mapping's CSV index is present, update row
                    if csv_row[column[0]].blank?
                      if current_mapping=='products' && column[1] =='name'
                        single_row['name'] = 'Product from Restore'
                      end
                    elsif !(current_mapping != 'products' && column[1] =='id')
                      if ['barcode','sku','category'].include? column[0]
                        single_row[column[1]] = csv_row[column[0]].strip
                      else
                        single_row[column[1]] = csv_row[column[0]]
                      end
                    end
                    # Add special mapping rules here. current_mapping is the key of mapping variable above
                    # single_row is the selected row of model marked under mapping[current_mapping]
                    # column[0] is csv_header column[1] is db_table_header
                    # happy coding!
                  end
                  single_row.save
                  if current_mapping == 'products'
                    unless csv_row['primary_sku'].blank?
                      single_row.primary_sku = csv_row['primary_sku']
                    end
                    unless csv_row['primary_barcode'].blank?
                      single_row.primary_barcode = csv_row['primary_barcode']
                    end
                    unless csv_row['primary_category'].blank?
                      single_row.primary_category = csv_row['primary_category']
                    end
                    unless csv_row['primary_image'].blank?
                      single_row.primary_image = csv_row['primary_image']
                    end
                    warehouse = ProductInventoryWarehouses.find_or_create_by_product_id_and_inventory_warehouse_id(single_row.id, InventoryWarehouse.where(:is_default => true).first.id)
                    default_warehouse_map.each do |warehouse_map|
                      warehouse[warehouse_map[1]] = csv_row[warehouse_map[0]]
                    end
                    warehouse.save
                    unless csv_row['is_kit'].blank?
                      products_to_check_later << single_row
                    end
                  end
                end
              end
            end
          end
        end
        products_to_check_later.each do |product|
          product.update_product_status
        end
      end
    else
      @result["status"] = false
      @result["messages"].push("User cannot restore backups")
    end

    respond_to do |format|
      format.json { render json: @result}
    end
  end

  def export_csv

    if current_user.can? 'create_backups'
      dir = Dir.mktmpdir([current_user.username+'groov-export-',Time.now.to_s])
      filename = 'groove-export-'+Time.now.to_s+'.zip'
      begin
        data = zip_to_files(filename,Product.to_csv(dir))

      ensure
        FileUtils.remove_entry_secure dir
      end
    else
      #prevent a fail and send empty zip
      filename = 'insufficient_permissions.zip'
      data = zip_to_files(filename,{})
    end

    respond_to do |format|
      format.html # show.html.erb
      format.zip { send_data  data,:type => 'application/zip', :filename => filename }
    end
  end

  def order_exceptions
    require 'csv'
    result = Hash.new
    result['status'] = true
    result['messages'] = []
    if current_user.can? 'view_packing_ex'
      if params[:start].nil? || params[:end].nil?
        result['status'] = false
        result['messages'].push('We need a start and an end time')
      else
        exceptions = OrderException.where(updated_at: Time.parse(params[:start])..Time.parse(params[:end]))
        filename = 'groove-order-exceptions-'+Time.now.to_s+'.csv'
        row_map = {
            :order_number => '',
            :order_date =>'',
            :scanned_date =>'',
            :packing_user =>'',
            :reason =>'',
            :description =>'',
            :associated_user =>'',
            :total_packed_items => '',
            :total_clicked_items => ''
        }
        data = CSV.generate do |csv|
          csv << row_map.keys

          exceptions.each do |exception|
            single_row = row_map.dup
            single_row[:order_number] = exception.order.increment_id
            single_row[:order_date] = exception.order.order_placed_time
            single_row[:scanned_date] = exception.order.scanned_on
            packing_user = nil
            packing_user = User.find(exception.order.packing_user_id) unless exception.order.packing_user_id.blank?
            unless packing_user.nil?
              single_row[:packing_user] = packing_user.name + ' ('+packing_user.username+')'
            end
            single_row[:reason] = exception.reason
            single_row[:description] = exception.description
            single_row[:associated_user] =  exception.user.name + ' ('+exception.user.username+')' unless exception.user.nil?
            single_row[:order_item_count] = exception.order.scanned_items_count
            single_row[:click_scanned_items] = exception.order.clicked_items_count
            csv << single_row.values
          end
        end

      end
    else
      result['status'] = false
      result['messages'].push('You do not have enough permissions to view packing exceptions')
    end

    unless result['status']
      data = CSV.generate do |csv|
        csv << result['messages']
      end
      filename = 'error.csv'
    end

    respond_to do |format|
      format.html # show.html.erb
      format.csv { send_data  data, :type => 'text/csv', :filename => filename }
    end
  end

  def order_serials
    require 'csv'
    result = Hash.new
    result['status'] = true
    result['messages'] = []
    if current_user.can? 'view_packing_ex'
      if params[:start].nil? || params[:end].nil?
        result['status'] = false
        result['messages'].push('We need a start and an end time')
      else
        serials = OrderSerial.where(updated_at: Time.parse(params[:start])..Time.parse(params[:end]))
        filename = 'groove-order-serials-'+Time.now.to_s+'.csv'
        row_map = {
            :order_date =>'',
            :order_number => '',
            :serial =>'',
            :primary_sku =>'',
            :primary_barcode =>'',
            :product_name=>'',
            :packing_user =>'',
            :order_item_count => '',
            :scanned_date =>'',
            :warehouse_name =>''
        }
        data = CSV.generate do |csv|
          csv << row_map.keys

          serials.each do |serial|
            single_row = row_map.dup
            single_row[:order_number] = serial.order.increment_id
            single_row[:order_date] = serial.order.order_placed_time
            single_row[:scanned_date] = serial.order.scanned_on
            packing_user = nil
            packing_user = User.find(serial.order.packing_user_id) unless serial.order.packing_user_id.blank?
            unless packing_user.nil?
              single_row[:packing_user] = packing_user.name + ' ('+packing_user.username+')'
              single_row[:warehouse_name] =  serial.product.primary_warehouse.inventory_warehouse.name unless serial.product.primary_warehouse.nil? || serial.product.primary_warehouse.inventory_warehouse.nil?
            end
            single_row[:serial] = serial.serial
            single_row[:product_name] = serial.product.name
            single_row[:primary_sku] =  serial.product.primary_sku
            single_row[:primary_barcode] =  serial.product.primary_barcode
            single_row[:order_item_count] = serial.order.get_items_count

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
      format.csv { send_data  data, :type => 'text/csv', :filename => filename }
    end
  end

  def get_columns_state
    @result = Hash.new
    @result['status'] = true
    @result['messages'] = []
    if params[:identifier].nil?
      @result['messages'].push("No Identifier for state preference given")
      @result['status'] = false
    else
      preference = ColumnPreference.find_by_user_id_and_identifier(current_user.id,params[:identifier])
      unless preference.nil?
        @result['data'] = preference
      end
    end
    respond_to do |format|
      format.html # show.html.erb
      format.json { render json:@result}
    end
  end

  def save_columns_state
    @result = Hash.new
    @result['status'] = true
    @result['messages'] = []
    if params[:identifier].nil?
      @result['messages'].push("No Identifier for state preference given")
      @result['status'] = false
    else
      preference = ColumnPreference.find_or_create_by_user_id_and_identifier(current_user.id,params[:identifier])
      preference.theads = params[:theads]
      preference.save!
    end
    respond_to do |format|
      format.html # show.html.erb
      format.json { render json:@result}
    end
  end

  def get_settings
    @result = Hash.new
    @result['status'] = true
    @result['error_messages'] = []
    @result['success_messages'] = []
    @result['notice_messages'] = []
    @result['data'] = Hash.new

    general_setting = GeneralSetting.all.first

    if !general_setting.nil?
      @result['data']['settings'] = general_setting
    else
      @result['status'] &= false
      @result['error_messages'].push('No general settings available for the system. Contact administrator.')
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end

  def update_settings
    @result = Hash.new
    @result['status'] = true
    @result['error_messages'] = []
    @result['success_messages'] = []
    @result['notice_messages'] = []

    general_setting = GeneralSetting.all.first

    if !general_setting.nil?
      if current_user.can? 'edit_general_prefs'
        general_setting.packing_slip_message_to_customer = params[:packing_slip_message_to_customer]
        general_setting.product_weight_format = params[:product_weight_format]
        general_setting.packing_slip_size = params[:packing_slip_size]
        if general_setting.packing_slip_size == '4 x 6'
          general_setting.packing_slip_orientation = 'portrait'
        else
          general_setting.packing_slip_orientation = params[:packing_slip_orientation]
        end
        general_setting.conf_req_on_notes_to_packer = params[:conf_req_on_notes_to_packer]
        general_setting.strict_cc = params[:strict_cc]
        general_setting.conf_code_product_instruction = params[:conf_code_product_instruction]
        general_setting.conf_req_on_notes_to_packer = params[:conf_req_on_notes_to_packer]
        general_setting.email_address_for_packer_notes = params[:email_address_for_packer_notes]
        general_setting.hold_orders_due_to_inventory = params[:hold_orders_due_to_inventory]
        general_setting.inventory_tracking = params[:inventory_tracking]
        general_setting.low_inventory_alert_email = params[:low_inventory_alert_email]
        general_setting.low_inventory_email_address = params[:low_inventory_email_address]
        general_setting.send_email_for_packer_notes = params[:send_email_for_packer_notes]
        general_setting.inventory_auto_allocation = params[:inventory_auto_allocation]
        if params[:default_low_inventory_alert_limit].to_i < 1
          params[:default_low_inventory_alert_limit] = 1
        end
        general_setting.default_low_inventory_alert_limit = params[:default_low_inventory_alert_limit].to_i


        general_setting.export_items = params[:export_items]


        general_setting.time_to_send_email = params[:time_to_send_email]
        general_setting.send_email_on_mon = params[:send_email_on_mon]
        general_setting.send_email_on_tue = params[:send_email_on_tue]
        general_setting.send_email_on_wed = params[:send_email_on_wed]
        general_setting.send_email_on_thurs = params[:send_email_on_thurs]
        general_setting.send_email_on_fri = params[:send_email_on_fri]
        general_setting.send_email_on_sat = params[:send_email_on_sat]
        general_setting.send_email_on_sun = params[:send_email_on_sun]

        general_setting.scheduled_order_import = params[:scheduled_order_import]
        general_setting.time_to_import_orders = params[:time_to_import_orders]
        general_setting.import_orders_on_mon = params[:import_orders_on_mon]
        general_setting.import_orders_on_tue = params[:import_orders_on_tue]
        general_setting.import_orders_on_wed = params[:import_orders_on_wed]
        general_setting.import_orders_on_thurs = params[:import_orders_on_thurs]
        general_setting.import_orders_on_fri = params[:import_orders_on_fri]
        general_setting.import_orders_on_sat = params[:import_orders_on_sat]
        general_setting.import_orders_on_sun = params[:import_orders_on_sun]

        general_setting.tracking_error_order_not_found = params[:tracking_error_order_not_found]
        general_setting.tracking_error_info_not_found = params[:tracking_error_info_not_found]

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
    result = Hash.new
    result['status'] = true
    result['success_messages'] = []
    result['notice_messages'] = []
    result['error_messages'] = []

    if params[:id].nil?
      result['status'] = false
      result['error_messages'].push('No id given. Can not cancel generating')
    else
      bulk_action = GrooveBulkActions.find_by_id(params[:id])
      unless bulk_action.nil?
        bulk_action.cancel = true
        if bulk_action.save
          result['notice_messages'].push('Bulk action marked for cancellation. Please wait for acknowledgement.')
        end
      else
        result['error_messages'].push('No bulk action found with the id.')
      end
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: result }
    end
  end

  def get_scan_pack_settings
    @result = Hash.new
    @result['status'] = true
    @result['error_messages'] = []
    @result['success_messages'] = []
    @result['notice_messages'] = []
    @result['settings'] = Hash.new

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
      format.pdf {
        render :pdf => 'action_barcode_'+params[:id].to_s,
               :template => 'settings/action_barcodes.html.erb',
               :orientation => 'Portrait',
               :page_height => '1in',
               :page_width => '3in',
               :margin => {
                   :top => '0',
                   :bottom => '0',
                   :left => '0',
                   :right => '0'
               }
      }
    end
  end

  def update_scan_pack_settings
    @result = Hash.new
    @result['status'] = true
    @result['error_messages'] = []
    @result['success_messages'] = []
    @result['notice_messages'] = []

    scan_pack_setting = ScanPackSetting.all.first

    if !scan_pack_setting.nil?
      if current_user.can? 'edit_scanning_prefs'
        scan_pack_setting.enable_click_sku = params[:enable_click_sku]
        scan_pack_setting.ask_tracking_number = params[:ask_tracking_number]
        scan_pack_setting.show_success_image = params[:show_success_image]
        scan_pack_setting.show_order_complete_image = params[:show_order_complete_image]
        #scan_pack_setting.success_image_src = params[:success_image_src]
        scan_pack_setting.success_image_time = params[:success_image_time]
        scan_pack_setting.order_complete_image_time = params[:order_complete_image_time]
        scan_pack_setting.play_success_sound = params[:play_success_sound]
        scan_pack_setting.play_order_complete_sound = params[:play_order_complete_sound]
        #scan_pack_setting.success_sound_vol = params[:success_sound_vol]
        #scan_pack_setting.success_sound_url = params[:success_sound_url]
        scan_pack_setting.show_fail_image = params[:show_fail_image]
        #scan_pack_setting.fail_image_src = params[:fail_image_src]
        scan_pack_setting.fail_image_time = params[:fail_image_time]
        scan_pack_setting.play_fail_sound = params[:play_fail_sound]
        #scan_pack_setting.fail_sound_vol = params[:fail_sound_vol]
        #scan_pack_setting.fail_sound_url = params[:fail_sound_url]
        scan_pack_setting.skip_code_enabled = params[:skip_code_enabled]
        scan_pack_setting.skip_code = params[:skip_code]
        scan_pack_setting.note_from_packer_code_enabled = params[:note_from_packer_code_enabled]
        scan_pack_setting.note_from_packer_code = params[:note_from_packer_code]
        scan_pack_setting.service_issue_code_enabled = params[:service_issue_code_enabled]
        scan_pack_setting.service_issue_code = params[:service_issue_code]
        scan_pack_setting.restart_code_enabled = params[:restart_code_enabled]
        scan_pack_setting.restart_code = params[:restart_code]
        scan_pack_setting.type_scan_code_enabled = params[:type_scan_code_enabled]
        scan_pack_setting.type_scan_code = params[:type_scan_code]
        scan_pack_setting.post_scanning_option = params[:post_scanning_option]
        scan_pack_setting.escape_string_enabled = params[:escape_string_enabled]
        scan_pack_setting.escape_string = params[:escape_string]
        scan_pack_setting.record_lot_number = params[:record_lot_number]
        scan_pack_setting.show_customer_notes = params[:show_customer_notes]
        scan_pack_setting.show_internal_notes = params[:show_internal_notes]
        scan_pack_setting.scan_by_tracking_number = params[:scan_by_tracking_number]

        if scan_pack_setting.save
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
    LowInventoryLevel.notify(GeneralSetting.all.first, Apartment::Tenant.current_tenant).deliver
    render json: "ok"
  end

end


