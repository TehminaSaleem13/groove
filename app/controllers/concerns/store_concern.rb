# frozen_string_literal: true

module StoreConcern
  extend ActiveSupport::Concern
  include StoresHelper

  def check_store_type
    init_store = Groovepacker::Stores::LibStores.new(@store, params, @result)
    case @store.store_type
    when 'Magento'
      @result = init_store.magento_update_create
    when 'Magento API 2'
      @result = init_store.magento_rest_update_create
    when 'Amazon'
      @result = init_store.amazon_update_create
    when 'Ebay'
      @result = init_store.ebay_update_create(session)
    when 'CSV' || 'system'
      @result = init_store.csv_update_create
    when 'Shippo'
      @result = init_store.shippo_update_create
    when 'Shipstation API 2'
      @result = init_store.shipstation_rest_update_create
    when 'ShippingEasy'
      @result = init_store.shipping_easy_update_create
    when 'Shipworks'
      @result = init_store.shipwork_update_create
    when 'Veeqo'
      @result = init_store.veeqo_update_create
    when 'Shopify'
      @result = init_store.shopify_update_create
      current_tenant = Apartment::Tenant.current
      $redis.set('tenant_name', current_tenant)
      $redis.set('store_id', @store.id)
      $redis.expire('tenant_name', 600)
      $redis.expire('store_id', 600)
    when 'Shopline'
      @result = init_store.shopline_update_create
      current_tenant = Apartment::Tenant.current
      $redis.set('tenant_name', current_tenant)
      $redis.set('store_id', @store.id)
      $redis.expire('tenant_name', 600)
      $redis.expire('store_id', 600)
    # cookies[:tenant_name] = {:value => current_tenant , :domain => :all, :expires => Time.current+10.minutes}
    # cookies[:store_id] = {:value => @store.id , :domain => :all, :expires => Time.current+10.minutes}
    when 'BigCommerce'
      @result = init_store.bigcommerce_update_create
      current_tenant = Apartment::Tenant.current
      cookies[:tenant_name] = { value: current_tenant, domain: :all, expires: Time.current + 20.minutes }
      cookies[:store_id] = { value: @store.id, domain: :all, expires: Time.current + 20.minutes }
    else
      @result = init_store.teapplix_update_create
    end
    @result
  end

  def order_csv_mapping(csv_map, csv_directory, current_tenant, default_csv_map)
    general_settings = GeneralSetting.all.first
    return unless %w[both order].include?(params[:type])

    @result['order'] = {}
    @result['order']['map_options'] =
      [{ value: 'increment_id', name: 'Order number' }, { value: 'order_placed_time', name: 'Order Date/Time' },
       { value: 'sku', name: 'SKU' }, { value: 'product_name', name: 'Product Name' }, { value: 'barcode', name: 'Barcode/UPC' }, { value: 'qty', name: 'QTY' }, { value: 'category', name: 'Product Category' }, { value: 'product_weight', name: 'Weight Oz' }, { value: 'product_instructions', name: 'Product Instructions' }, { value: 'image', name: 'Image Absolute URL' }, { value: 'firstname', name: '(First)Full Name' }, { value: 'lastname', name: 'Last Name' }, { value: 'email', name: 'Email' }, { value: 'address_1', name: 'Address 1' }, { value: 'address_2', name: 'Address 2' }, { value: 'city', name: 'City' }, { value: 'state', name: 'State' }, { value: 'postcode', name: 'Postal Code' }, { value: 'country', name: 'Country' }, { value: 'method', name: 'Shipping Method' }, { value: 'price', name: 'Order Total' }, { value: 'customer_comments', name: 'Customer Comments' }, { value: 'notes_internal', name: 'Internal Notes' }, { value: 'tags', name: 'Tags' }, { value: 'notes_toPacker', name: 'Notes to Packer' }, { value: 'tracking_num', name: 'Tracking Number' }, { value: 'item_sale_price', name: 'Item Sale Price' }, { value: 'secondary_sku', name: 'SKU 2' }, { value: 'tertiary_sku', name: 'SKU 3' }, { value: 'secondary_barcode', name: 'Barcode 2' }, { value: 'tertiary_barcode', name: 'Barcode 3' }, { value: 'custom_field_one', name: general_settings.custom_field_one }, { value: 'custom_field_two', name: general_settings.custom_field_two }, { value: 'bin_location', name: 'Primary Location' }]
    if csv_map.order_csv_map.blank?
      @result['order']['settings'] = default_csv_map
    else
      temp_mapping = Groovepacker::Utilities::Base.new.fix_corrupted_map(csv_map.order_csv_map)[:map]
      begin
        new_map = temp_mapping[:map].each_with_object({}) do |(k, v), hash|
          hash[k] =
            (if v['value'].in?(%w[custom_field_one
                                  custom_field_two])
               v.merge('name' => general_settings[v['value']])
             else
               v
             end)
        end
      rescue Exception => e
        new_map = temp_mapping[:map].to_unsafe_h.each_with_object({}) do |(k, v), hash|
          hash[k] =
            (if v['value'].in?(%w[custom_field_one
                                  custom_field_two])
               v.merge('name' => general_settings[v['value']])
             else
               v
             end)
        end
      end
      if csv_map.order_csv_map.map != temp_mapping.merge(map: new_map)
        csv_map.order_csv_map.update(map: temp_mapping.merge(map: new_map))
      end
      @result['order']['settings'] = csv_map.order_csv_map
    end
    order_file_path = File.join(csv_directory, "#{current_tenant}.#{@store.id}.order.csv")
    return unless File.exist? order_file_path

    order_file_data = csv_data('order')
    @result['order']['data'] = order_file_data.force_encoding('ISO-8859-1').encode('UTF-8')
    File.delete(order_file_path)
    $redis.del("#{ENV['S3_BASE_URL']}/#{current_tenant}/csv/order.#{@store.id}.csv")
  end

  def csv_data(kind)
    current_tenant = Apartment::Tenant.current
    begin
      begin
        @file_data = $redis.get("#{ENV['S3_BASE_URL']}/#{current_tenant}/csv/#{kind}.#{@store.id}.csv").encode('UTF-8').split("\n").first(30).join("\n").gsub("\r\n", "\n").tr(
          "\r", "\n"
        )
      rescue StandardError
        @file_data = $redis.get("#{ENV['S3_BASE_URL']}/#{current_tenant}/csv/#{kind}.#{@store.id}.csv").force_encoding('ISO-8859-1').split("\n").first(30).join("\n").gsub("\r\n", "\n").tr(
          "\r", "\n"
        )
      end
    rescue StandardError
      @file_data = $redis.get("#{ENV['S3_BASE_URL']}/#{current_tenant}/csv/#{kind}.#{@store.id}.csv")
      unless @file_data.nil?
        @file_data = begin
          @file_data.gsub("\r\n", "\n")
        rescue StandardError
          @file_data
        end
      end
    end
    @file_data.gsub!("\"\"", '')
    @file_data
  end

  def product_kit_csv_map(csv_map, csv_directory, current_tenant, default_csv_map)
    if %w[both product].include?(params[:type])
      @result['product'] = {}
      @result['product']['map_options'] =
        [{ value: 'product_name', name: 'Product Name' }, { value: 'sku', name: 'SKU 1' },
         { value: 'secondary_sku', name: 'SKU 2' }, { value: 'tertiary_sku', name: 'SKU 3' }, { value: 'quaternary_sku', name: 'SKU 4' }, { value: 'quinary_sku', name: 'SKU 5' }, { value: 'senary_sku', name: 'SKU 6' }, { value: 'barcode', name: 'Barcode 1' }, { value: 'barcode_qty', name: 'Barcode 1 qty' }, { value: 'secondary_barcode', name: 'Barcode 2' }, { value: 'secondary_barcode_qty', name: 'Barcode 2 Qty' }, { value: 'tertiary_barcode', name: 'Barcode 3' }, { value: 'tertiary_barcode_qty', name: 'Barcode 3 Qty' }, { value: 'quaternary_barcode', name: 'Barcode 4' }, { value: 'quaternary_barcode_qty', name: 'Barcode 4 Qty' }, { value: 'quinary_barcode', name: 'Barcode 5' }, { value: 'quinary_barcode_qty', name: 'Barcode 5 Qty' }, { value: 'senary_barcode', name: 'Barcode 6' }, { value: 'senary_barcode_qty', name: 'Barcode 6 Qty' }, { value: 'location_primary', name: 'Location 1' }, { value: 'location_primary_qty', name: 'Location 1 Qty' }, { value: 'location_secondary', name: 'Location 2' }, { value: 'location_secondary_qty', name: 'Location 2 Qty' }, { value: 'location_tertiary', name: 'Location 3' }, { value: 'location_tertiary_qty', name: 'Location 3 Qty' }, { value: 'location_quaternary', name: 'Location 4' }, { value: 'location_quaternary_qty', name: 'Location 4 Qty' }, { value: 'inv_wh1', name: 'Qty On Hand' }, { value: 'product_images', name: 'Absolute Image URL' }, { value: 'product_instructions', name: 'Packing Instructions' }, { value: 'packing_instructions_conf', name: 'Packing Instructions Conf' }, { value: 'receiving_instructions', name: 'Product Receiving Instructions' }, { value: 'category_name', name: 'Categories' }, { value: 'fnsku', name: 'FNSKU' }, { value: 'asin', name: 'ASIN' }, { value: 'fba_upc', name: 'FBA-UPC' }, { value: 'isbn', name: 'ISBN' }, { value: 'ean', name: 'EAN' }, { value: 'supplier_sku', name: 'Supplier SKU' }, { value: 'avg_cost', name: 'AVG Cost' }, { value: 'count_group', name: 'Count Group' }, { value: 'restock_lead_time', name: 'Restock Lead Time' }, { value: 'packing_placement', name: 'Product Scanning Sequence' }, { value: 'custom_product_1', name: 'Custom Product 1' }, { value: 'custom_product_display_1', name: 'Custom Product Display 1' }, { value: 'custom_product_2', name: 'Custom Product 2' }, { value: 'custom_product_display_2', name: 'Custom Product Display 2' }, { value: 'custom_product_3', name: 'Custom Product 3' }, { value: 'custom_product_display_3', name: 'Custom Product Display 3' }, { value: 'click_scan_enabled', name: 'Opt. Click Scan' }, { value: 'type_scan_enabled', name: 'Opt. Type-in Count' }, { value: 'is_intangible', name: 'Opt. Intangible' }, { value: 'add_to_any_order', name: 'Opt. Add to Any Order' }, { value: 'is_skippable', name: 'Opt. Skippable' }, { value: 'product_record_serial', name: 'Opt. Record Serial 1' }, { value: 'product_second_record_serial', name: 'Opt. Record Serial 2' }, { value: 'product_inv_alert_level', name: 'Inv. Alert Level' }, { value: 'product_inv_target_level', name: 'Inventory Target Level' }, { value: 'remove_sku', name: 'Remove This SKU' }]
      @result['product']['settings'] = csv_map.product_csv_map.nil? ? default_csv_map : csv_map.product_csv_map
      product_file_path = File.join(csv_directory, "#{current_tenant}.#{@store.id}.product.csv")
      if File.exist? product_file_path
        product_file_data = csv_data('product')
        # product_file_data = Net::HTTP.get(URI.parse("#{ENV['S3_BASE_URL']}/#{current_tenant}/csv/product.#{@store.id}.csv")).split(/[\r\n]+/).first(200).join("\r\n")
        @result['product']['data'] = product_file_data.force_encoding('ISO-8859-1').encode('UTF-8')
        File.delete(product_file_path)
        $redis.del("#{ENV['S3_BASE_URL']}/#{current_tenant}/csv/product.#{@store.id}.csv")
      end
    end
    return unless %w[both kit].include?(params[:type])

    @result['kit'] = {}
    @result['kit']['map_options'] =
      [{ value: 'kit_sku', name: 'KIT-SKU' }, { value: 'kit_name', name: 'KIT-NAME' },
       { value: 'kit_barcode', name: 'KIT-BARCODE' }, { value: 'part_sku', name: 'PART-SKU' }, { value: 'part_name', name: 'PART-NAME' }, { value: 'part_barcode', name: 'PART-BARCODE' }, { value: 'part_qty', name: 'PART-QTY' }, { value: 'scan_option', name: 'SCAN-OPTION' }, { value: 'kit_part_scanning_sequence', name: 'KIT-PART-SCANNING-SEQUENCE' }]
    @result['kit']['settings'] = csv_map.kit_csv_map.nil? ? default_csv_map : csv_map.kit_csv_map
    kit_file_path = File.join(csv_directory, "#{current_tenant}.#{@store.id}.kit.csv")
    return unless File.exist? kit_file_path

    kit_file_data = csv_data('kit')
    # kit_file_data = Net::HTTP.get(URI.parse("#{ENV['S3_BASE_URL']}/#{current_tenant}/csv/kit.#{@store.id}.csv")).split(/[\r\n]+/).first(200).join("\r\n")
    @result['kit']['data'] = kit_file_data
    File.delete(kit_file_path)
    $redis.del("#{ENV['S3_BASE_URL']}/#{current_tenant}/csv/kit.#{@store.id}.csv")
  end

  def check_csv_condition
    (params[:type] == 'order' && current_user.can?('import_orders')) || (params[:type] == 'both' && current_user.can?('import_orders') && current_user.can?('import_products')) || (%w[
      product kit
    ].include?(params[:type]) && current_user.can?('import_products'))
  end

  def csv_data_import
    if !@store.nil?
      params[:type] = 'both' if params[:type].nil? || !%w[both order product kit].include?(params[:type])
      if check_csv_condition
        @result['store_id'] = @store.id
        default_csv_map = { 'name' => '',
                            'map' => { 'rows' => 2, 'sep' => ',', 'other_sep' => 0, 'delimiter' => '"', 'fix_width' => 0, 'fixed_width' => 4,
                                       'contains_unique_order_items' => false, 'generate_barcode_from_sku' => false, 'use_sku_as_product_name' => false, 'order_placed_at' => nil, 'order_date_time_format' => 'Default', 'day_month_sequence' => 'MM/DD', 'map' => {}, 'encoding_format' => 'ASCII + UTF-8' } }
        csv_map = CsvMapping.find_or_create_by(store_id: @store.id)
        csv_directory = 'uploads/csv'
        current_tenant = Apartment::Tenant.current
        order_csv_mapping(csv_map, csv_directory, current_tenant, default_csv_map)
        product_kit_csv_map(csv_map, csv_directory, current_tenant, default_csv_map)
      else
        @result['status'] = false
        @result['messages'].push('Not enough permissions')
      end
    else
      @result['status'] = false
      @result['messages'].push('Cannot find store')
    end
    @result
  end

  def data_import
    @result = { 'status' => true, 'messages' => [] }
    # general_settings = GeneralSetting.all.first
    if !params[:id].nil?
      @store = Store.find(params[:id])
    else
      @result['status'] = false
      @result['messages'].push('No store selected')
    end
    csv_data_import if @result['status']
  end

  def check_store
    if params[:store_id]
      @store = Store.find_by_id params[:id]
      if @store.nil?
        @result['status'] = false
        @result['messages'].push('Store doesn\'t exist')
      end
    else
      @result['status'] = false
      @result['messages'].push('No store selected')
    end
  end

  def check_store_status
    if !@store.try(:status) && (params['flag'] == 'ftp_download')
      @result['status'] = false
      @result['messages'].push('Store is not active')
    end
    if params[:type].nil? || !%w[order product kit].include?(params[:type])
      @result['status'] = false
      @result['messages'].push('No Type specified to import')
    end
    if (params[:type] == 'order' && !current_user.can?('import_orders')) || (%w[product
                                                                                kit].include?(params[:type]) && !current_user.can?('import_products'))
      @result['status'] = false
      @result['messages'].push("User does not have permissions to import #{params[:type]}")
    end
  end

  def csv_store_map_data
    csv_map = CsvMapping.find_by_store_id(@store.id)
    if params[:type] == 'product'
      params[:name] = csv_map.store.name + ' - Default Product Map' if params[:name].blank?
      if csv_map.product_csv_map_id.nil?
        map_data = CsvMap.create(kind: 'product', name: params[:name], map: {})
        csv_map.product_csv_map_id = map_data.id
      else
        map_data = csv_map.product_csv_map
      end
    elsif params[:type] == 'kit'
      params[:name] = csv_map.store.name + ' - Default Kit Map' if params[:name].blank?
      if csv_map.kit_csv_map_id.nil?
        map_data = CsvMap.create(kind: 'kit', name: params[:name], map: {})
        csv_map.kit_csv_map_id = map_data.id
      else
        map_data = csv_map.kit_csv_map
      end
    elsif params[:type] == 'order'
      params[:name] = csv_map.store.name + ' - Default Order Map' if params[:name].blank?
      if csv_map.order_csv_map_id.nil?
        map_data = CsvMap.create(kind: 'order', name: params[:name], map: {})
        csv_map.order_csv_map_id = map_data.id
      else
        map_data = csv_map.order_csv_map
      end
    end
    begin
      map_data.name = params[:name]
      map = begin
        params[:map].permit!.to_h
      rescue StandardError
        params[:map]
      end
      map_data.map = { rows: params[:rows], sep: params[:sep], other_sep: params[:other_sep],
                       delimiter: params[:delimiter], fix_width: params[:fix_width], fixed_width: params[:fixed_width], import_action: params[:import_action], generate_placeholder_barcodes: params[:generate_placeholder_barcodes], contains_unique_order_items: params[:contains_unique_order_items], generate_barcode_from_sku: params[:generate_barcode_from_sku], use_sku_as_product_name: params[:use_sku_as_product_name], permit_duplicate_barcodes: params[:permit_duplicate_barcodes], order_date_time_format: params[:order_date_time_format], day_month_sequence: params[:day_month_sequence], encoding_format: params[:encoding_format], map: }
      map_data.save!
      map_data.map[:map].values.each_with_index do |data, index|
        $redis.set("#{Apartment::Tenant.current}_csv_file_increment_id_index", index) if data[:value] == 'increment_id'
      end
      csv_map.save!
    rescue ActiveRecord::RecordInvalid
      @result['status'] = false
      @result['messages'].push(csv_map.errors.full_messages)
      @result['messages'].push(map_data.errors.full_messages)
      @result['messages'] = @result['messages'].reject(&:empty?)
    rescue ActiveRecord::StatementInvalid => e
      @result['status'] = false
      @result['messages'].push(e.message)
    end
  end

  def nil_csv_map(result)
    if params[:kind].nil? || params[:id].nil?
      result['status'] = false
      result['messages'].push('You need kind and store id to delete csv map')
    else
      mapping = CsvMapping.find_or_create_by(store_id: params[:id])
      if params[:kind] == 'order'
        mapping.order_csv_map_id = nil
      elsif params[:kind] == 'product'
        mapping.product_csv_map_id = nil
      elsif params[:kind] == 'kit'
        mapping.kit_csv_map_id = nil
      end
      mapping.save
    end
    result
  end

  def update_map(result)
    if params[:map].nil? || params[:id].nil?
      result['status'] = false
      result['messages'].push('You need map and store id to update csv map')
    else
      mapping = CsvMapping.find_or_create_by(store_id: params[:id])
      if params[:map]['kind'] == 'order'
        mapping.order_csv_map_id = params[:map]['id']
      elsif params[:map]['kind'] == 'product'
        mapping.product_csv_map_id = params[:map]['id']
      elsif params[:map]['kind'] == 'kit'
        mapping.kit_csv_map_id = params[:map]['id']
      end
      mapping.save
    end
    result
  end

  def update_ftp(store, result)
    ftp = store.ftp_credential
    if ftp.nil?
      ftp = FtpCredential.new
      new_record = true
    end
    params[:host] = nil if params[:host] === 'null'
    ftp.assign_attributes(host: params[:host], username: params[:username], password: params[:password],
                          connection_method: params[:connection_method], connection_established: false, use_ftp_import: params[:use_ftp_import], product_ftp_host: params[:product_ftp_host], product_ftp_username: params[:product_ftp_username], product_ftp_password: params[:product_ftp_password], product_ftp_connection_method: params[:product_ftp_connection_method], product_ftp_connection_established: false, use_product_ftp_import: params[:use_product_ftp_import])
    store.ftp_credential = ftp
    begin
      store.save!
      store.ftp_credential.save unless new_record
    rescue ActiveRecord::RecordInvalid
      result['status'] = false
      result['messages'] = [store.errors.full_messages, store.ftp_credential.errors.full_messages]
    rescue ActiveRecord::StatementInvalid => e
      result['status'] = false
      result['messages'] = [e.message]
    end
    result
  end

  def create_handler
    case @store.store_type
    when 'BigCommerce'
      handler = Groovepacker::Stores::Handlers::BigCommerceHandler.new(@store)
    when 'Magento API 2'
      handler = Groovepacker::Stores::Handlers::MagentoRestHandler.new(@store)
    when 'Shopify'
      handler = Groovepacker::Stores::Handlers::ShopifyHandler.new(@store)
    when 'Shopline'
      handler = Groovepacker::Stores::Handlers::ShoplineHandler.new(@store)
    when 'Teapplix'
      handler = Groovepacker::Stores::Handlers::TeapplixHandler.new(@store)
    end
    Groovepacker::Stores::Context.new(handler)
  end

  def cancel_product_import
    result = { 'status' => true, 'success_messages' => [], 'notice_messages' => [], 'error_messages' => [] }
    if params[:id].nil?
      result['status'] = false
      result['error_messages'].push('No id given. Can not cancel product import')
    else
      product_import = CsvProductImport.find_by_id(params[:id])
      product_import.cancel = true
      unless product_import.status == 'in_progress'
        product_import.status = 'cancelled'
        begin
          Delayed::Job.find(product_import.delayed_job_id).destroy
        rescue StandardError
          nil
        end
      end
      if product_import.save
        result['notice_messages'].push('Product Import marked for cancellation. Please wait for acknowledgement.')
      end
    end
    result
  end

  def push_pull_inventory(flag)
    @store = Store.find(params[:id])
    @result = { 'status' => true }
    @result['status'] = true
    tenant = Apartment::Tenant.current
    import_orders_obj = ImportOrders.new
    import_orders_obj.delay(run_at: 1.second.from_now, queue: "start_import_#{Apartment::Tenant.current}",
                            priority: 95).init_import(tenant)
    if @store && current_user.can?('update_inventories')
      context = create_handler
      if @store.store_type == 'Shopify'
        case flag
        when 'push'
          Groovepacker::Stores::Exporters::Shopify::Inventory.new(tenant, @store.id)
                                                             .delay(run_at: 1.second.from_now, queue: "push_inventory_#{tenant}", priority: 95)
                                                             .push_inventories
        when 'pull'
          Groovepacker::Stores::Importers::ShopInventoryImporter.new(tenant, @store.id)
                                                                .delay(run_at: 1.second.from_now, queue: "pull_inventory_#{tenant}", priority: 95)
                                                                .pull_inventories
        end
      elsif @store.store_type == 'Shopline'
        case flag
        when 'push'
          Groovepacker::Stores::Exporters::Shopline::Inventory.new(tenant, @store.id)
                                                              .delay(run_at: 1.second.from_now, queue: "push_inventory_#{tenant}", priority: 95)
                                                              .push_inventories
        when 'pull'
          Groovepacker::Stores::Importers::ShopInventoryImporter.new(tenant, @store.id)
                                                                .delay(run_at: 1.second.from_now, queue: "pull_inventory_#{tenant}", priority: 95)
                                                                .pull_inventories
        end
      elsif flag == 'push'
        context.delay(run_at: 1.second.from_now, queue: 'push_inventory', priority: 95).push_inventory
      elsif flag == 'pull'
        context.delay(run_at: 1.second.from_now, queue: 'pull_inventory', priority: 95).pull_inventory
        @result['message'] = 'Your request for innventory pull has beed queued'
      end
    else
      @result['status'] = false
      if flag == 'push'
        @result['message'] =
          "Either the store is not present or you don't have permissions to update inventories."
      else
        @result['message'] =
          "Either the the BigCommerce store is not setup properly or you don't have permissions to update inventories."
      end
    end
  end
end
