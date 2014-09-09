class SettingsController < ApplicationController

  include SettingsHelper
  def restore
    @result = Hash.new
    @result['status'] = true
    @result['messages'] = []
    if current_user.can? 'restore_backups'
        # Every entry on mapping[current_mapping][:map] should be in the format
      # csv_header => db_table_header
      mapping = {
          'products' => {
              model: Product,
              map: {
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
                  'alternate_location' => 'alternate_location',
                  'barcode' => 'barcode',
                  'is_skippable' => 'is_skippable',
                  'packing_placement' => 'packing_placement',
                  'pack_time_adj' => 'pack_time_adj',
                  'kit_parsing' => 'kit_parsing',
                  'is_kit' => 'is_kit',
                  'disable_conf_req' => 'disable_conf_req',
                  'total_avail_ext' =>'total_avail_ext',
                  'weight' =>'weight',
                  'shipping_weight'=>'shipping_weight',
                  'is_packing_supply' =>'is_packing_supply'
              }
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

      default_warehouse_map = {
          'default_wh_avbl' => 'available_inv',
          'default_wh_loc_primary' =>'location_primary',
          'default_wh_loc_secondary' => 'location_secondary'
      }


      if params[:method].nil? || !['del_import','update_only'].include?(params[:method])
        @result['status'] = false
        @result.messages.push("No action selected")
      elsif params[:file].nil?
        @result['status'] = false
        @result.messages.push("No file selected")
      else
        require 'zip'
        require 'csv'
        # Clear tables if delete method is invoked
        if params[:method] == 'del_import'
          mapping.each do |single_map|
            single_map[1][:model].delete_all
          end
        end
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
                # Create new row if deleted all else find and select by id for updating
                if params[:method] == 'del_import'
                  if current_mapping == 'product_barcodes'
                    all_rows = mapping[current_mapping][:model].where(:barcode =>csv_row['barcode'],:product_id=>csv_row['product_id'])
                    if all_rows.length >0
                      single_row = all_rows.first
                    end
                  elsif current_mapping == 'product_skus'
                    all_rows = mapping[current_mapping][:model].where(:sku =>csv_row['sku'],:product_id=>csv_row['product_id'])
                    if all_rows.length >0
                      single_row = all_rows.first
                    end
                  elsif current_mapping == 'product_cats'
                    all_rows = mapping[current_mapping][:model].where(:category =>csv_row['category'],:product_id=>csv_row['product_id'])
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
                  end
                else
                  single_row = mapping[current_mapping][:model].find_by_id(csv_row['id'])
                end

                unless single_row.nil?
                  # Now loop through all our defined mappings to check and update values
                  mapping[current_mapping][:map].each do |column|
                    # If mapping's CSV index is present, update row
                    unless csv_row[column[0]].nil?
                      single_row[column[1]] = csv_row[column[0]]
                    end
                    # Add special mapping rules here. current_mapping is the key of mapping variable above
                    # single_row is the selected row of model marked under mapping[current_mapping]
                    # column[0] is csv_header column[1] is db_table_header
                    # happy coding!
                  end
                  single_row.save!
                  if current_mapping == 'products'
                    unless csv_row['primary_sku'].blank?
                      sku =  ProductSku.find_or_create_by_sku_and_product_id(csv_row['primary_sku'],single_row.id)
                      sku.order = 0
                      sku.save
                    end
                    unless csv_row['primary_barcode'].blank?
                      barcode = ProductBarcode.find_or_create_by_barcode_and_product_id(csv_row['primary_barcode'],single_row.id)
                      barcode.order = 0
                      barcode.save
                    end
                    unless csv_row['primary_category'].blank?
                      category = ProductCat.find_or_create_by_category_and_product_id(csv_row['primary_category'],single_row.id)
                      category.save
                    end
                    unless csv_row['primary_image'].blank?
                      image = ProductImage.find_or_create_by_image_and_product_id(csv_row['primary_image'],single_row.id)
                      image.order = 0
                      image.save
                    end
                    warehouse = ProductInventoryWarehouses.find_or_create_by_product_id_and_inventory_warehouse_id(single_row.id, InventoryWarehouse.where(:is_default => true).first.id)
                    default_warehouse_map.each do |warehouse_map|
                      warehouse[warehouse_map[1]] = csv_row[warehouse_map[0]]
                    end
                    warehouse.save
                    single_row.update_product_status
                  end

                end
              end
            end
          end
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
      filename = 'groov-export-'+Time.now.to_s+'.zip'
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
        general_setting.email_address_for_packer_notes = params[:email_address_for_packer_notes]
        general_setting.hold_orders_due_to_inventory = params[:hold_orders_due_to_inventory]
        general_setting.inventory_tracking = params[:inventory_tracking]
        general_setting.low_inventory_alert_email = params[:low_inventory_alert_email]
        general_setting.low_inventory_email_address = params[:low_inventory_email_address]
        general_setting.send_email_for_packer_notes = params[:send_email_for_packer_notes]
        general_setting.default_low_inventory_alert_limit = params[:default_low_inventory_alert_limit]

        
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

  def send_test_mail
    LowInventoryLevel.notify(GeneralSetting.all.first, Apartment::Tenant.current_tenant).deliver
    render json: "ok"
  end

end


