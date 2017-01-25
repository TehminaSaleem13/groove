module StoreConcern
 extend ActiveSupport::Concern
 include StoresHelper

 def check_store_type
  init_store = Groovepacker::Stores::Stores.new(@store, params, @result)
  case @store.store_type
  when 'Magento'		
  @result = init_store.magento_update_create
  when "Magento API 2"
    @result = init_store.magento_rest_update_create
  when 'Amazon'
    @result = init_store.amazon_update_create 
  when 'Ebay'
    @result = init_store.ebay_update_create(session)
  when	'CSV' || 'system'
    @result = init_store.csv_update_create
  when 'Shipstation API 2'
    @result = init_store.shipstation_rest_update_create
  when 'ShippingEasy'
    @result = init_store.shipping_easy_update_create
  when 'Shipworks'
    @result = init_store.shipwork_update_create
  when 'Shopify'
    @result = init_store.shopify_update_create
    current_tenant = Apartment::Tenant.current
    cookies[:tenant_name] = {:value => current_tenant , :domain => :all, :expires => Time.now+10.minutes}
    cookies[:store_id] = {:value => @store.id , :domain => :all, :expires => Time.now+10.minutes}
   when 'BigCommerce'
     @result = init_store.bigcommerce_update_create
     current_tenant = Apartment::Tenant.current
    cookies[:tenant_name] = {:value => current_tenant , :domain => :all, :expires => Time.now+20.minutes}
    cookies[:store_id] = {:value => @store.id , :domain => :all, :expires => Time.now+20.minutes}
   else
     @result = init_store.teapplix_update_create
   end
   @result
 end

  def order_csv_mapping(csv_map, csv_directory, current_tenant, default_csv_map)
    general_settings = GeneralSetting.all.first
    if ['both', 'order'].include?(params[:type])
      @result['order'] = Hash.new
      @result['order']['map_options'] = [{value: 'increment_id', name: 'Order number'},{value: 'order_placed_time', name: 'Order Date/Time'},{value: 'sku', name: 'SKU'}, {value: 'product_name', name: 'Product Name'}, {value: 'barcode', name: 'Barcode/UPC'}, {value: 'qty', name: 'QTY'}, {value: 'category', name: 'Product Category'}, {value: 'product_weight', name: 'Weight Oz'}, {value: 'product_instructions', name: 'Product Instructions'}, {value: 'image', name: 'Image Absolute URL'}, {value: 'firstname', name: '(First)Full Name'}, {value: 'lastname', name: 'Last Name'}, {value: 'email', name: 'Email'}, {value: 'address_1', name: 'Address 1'}, {value: 'address_2', name: 'Address 2'}, {value: 'city', name: 'City'}, {value: 'state', name: 'State'}, {value: 'postcode', name: 'Postal Code'}, {value: 'country', name: 'Country'}, {value: 'method', name: 'Shipping Method'}, {value: 'price', name: 'Order Total'}, {value: 'customer_comments', name: 'Customer Comments'}, {value: 'notes_internal', name: 'Internal Notes'}, {value: 'notes_toPacker', name: 'Notes to Packer'}, {value: 'tracking_num', name: 'Tracking Number'}, {value: 'item_sale_price', name: 'Item Sale Price'}, {value: 'secondary_sku', name: 'SKU 2'}, {value: 'tertiary_sku', name: 'SKU 3'}, {value: 'secondary_barcode', name: 'Barcode 2'}, {value: 'tertiary_barcode', name: 'Barcode 3'}, {value: 'custom_field_one', name: general_settings.custom_field_one}, {value: 'custom_field_two', name: general_settings.custom_field_two}]
      if csv_map.order_csv_map.nil?
        @result['order']['settings'] = default_csv_map
      else
        temp_mapping = csv_map.order_csv_map[:map]
        new_map = temp_mapping[:map].inject({}){|hash, (k, v)| hash.merge!(k => (v['value'].in?(%w(custom_field_one custom_field_two)) ? v.merge('name' => general_settings[v['value']]) : v)); hash}
        csv_map.order_csv_map.update_attributes(map: temp_mapping.merge(map: new_map))
        @result['order']['settings'] = csv_map.order_csv_map
      end
      order_file_path = File.join(csv_directory, "#{current_tenant}.#{@store.id}.order.csv")
      if File.exist? order_file_path
        order_file_data = csv_data('order')
        @result['order']['data'] = order_file_data
        File.delete(order_file_path)
      end
    end
  end
  
  def csv_data(kind)
    3.times do
      current_tenant = Apartment::Tenant.current
      @file_data = Net::HTTP.get(URI.parse("#{ENV['S3_BASE_URL']}/#{current_tenant}/csv/#{kind}.#{@store.id}.csv")).split(/[\r\n]+/).first(200).join("\r\n")
      break if @file_data.present?
      sleep(1)
    end
    @file_data
  end

  def product_kit_csv_map(csv_map, csv_directory, current_tenant, default_csv_map)
    if ['both', 'product'].include?(params[:type])
      @result['product'] = Hash.new
      @result['product']['map_options'] = [ {value: 'sku', name: 'SKU'}, {value: 'barcode', name: 'Barcode'}, {value: 'product_name', name: 'Name'}, {value: 'inv_wh1', name: 'QTY On Hand'}, {value: 'location_primary', name: 'Bin Location'}, {value: 'product_images', name: 'Image Absolute URL'}, {value: 'product_weight', name: 'Weight Oz'}, {value: 'category_name', name: 'Category'}, {value: 'product_instructions', name: 'Packing Instructions'}, {value: 'receiving_instructions', name: 'Receiving Instructions'}, {value: 'secondary_sku', name: 'SKU 2'}, {value: 'tertiary_sku', name: 'SKU 3'}, {value: 'secondary_barcode', name: 'Barcode 2'}, {value: 'tertiary_barcode', name: 'Barcode 3'}, {value: 'location_secondary', name: 'Bin Location 2'}, {value: 'location_tertiary', name: 'Bin Location 3'}]
      @result['product']['settings'] = csv_map.product_csv_map.nil? ? default_csv_map : csv_map.product_csv_map
      product_file_path = File.join(csv_directory, "#{current_tenant}.#{@store.id}.product.csv")
      if File.exist? product_file_path
        product_file_data = csv_data('product')
        # product_file_data = Net::HTTP.get(URI.parse("#{ENV['S3_BASE_URL']}/#{current_tenant}/csv/product.#{@store.id}.csv")).split(/[\r\n]+/).first(200).join("\r\n")
        @result['product']['data'] = product_file_data
        File.delete(product_file_path)
      end
    end
    if ['both', 'kit'].include?(params[:type])
      @result['kit'] = Hash.new
      @result['kit']['map_options'] = [{value: 'kit_sku', name: 'KIT-SKU'}, {value: 'kit_name', name: 'KIT-NAME'}, {value: 'kit_barcode', name: 'KIT-BARCODE'}, {value: 'part_sku', name: 'PART-SKU'},{value: 'part_name', name: 'PART-NAME'}, {value: 'part_barcode', name: 'PART-BARCODE'}, {value: 'part_qty', name: 'PART-QTY'}, {value: 'scan_option', name:'SCAN-OPTION' }]
      @result['kit']['settings'] = csv_map.kit_csv_map.nil? ? default_csv_map : csv_map.kit_csv_map
      kit_file_path = File.join(csv_directory, "#{current_tenant}.#{@store.id}.kit.csv")
      if File.exist? kit_file_path
        kit_file_data = csv_data('kit')
        # kit_file_data = Net::HTTP.get(URI.parse("#{ENV['S3_BASE_URL']}/#{current_tenant}/csv/kit.#{@store.id}.csv")).split(/[\r\n]+/).first(200).join("\r\n")
        @result['kit']['data'] = kit_file_data
        File.delete(kit_file_path)
      end
    end
  end

  def check_csv_condition
    (params[:type] == 'order' && current_user.can?('import_orders')) || (params[:type] == 'both' && current_user.can?('import_orders') && current_user.can?('import_products')) || (['product', 'kit'].include?(params[:type]) && current_user.can?('import_products'))
  end

  def csv_data_import
    if !@store.nil?
      params[:type] = 'both' if params[:type].nil? || !['both', 'order', 'product', 'kit'].include?(params[:type])
      if check_csv_condition
        @result['store_id'] = @store.id
        default_csv_map = { 'name' => '', 'map' => {'rows' => 2,'sep' => ',','other_sep' => 0,'delimiter' => '"','fix_width' => 0,'fixed_width' => 4, 'contains_unique_order_items' => false,'generate_barcode_from_sku' => false, 'use_sku_as_product_name' => false, 'order_placed_at' => nil,'order_date_time_format' => 'Default','day_month_sequence' => 'MM/DD','map' => {}}}
        csv_map = CsvMapping.find_or_create_by_store_id(@store.id)
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
  end

  def data_import
    @result = {"status"=>true, "messages"=>[]}
    # general_settings = GeneralSetting.all.first
    if !params[:id].nil?
      @store = Store.find(params[:id])
    else
      @result["status"] = false
      @result["messages"].push("No store selected")
    end
    csv_data_import if @result["status"] 
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
    unless @store.status
      if params["flag"]=="ftp_download"
        @result['status'] = false
        @result['messages'].push('Store is not active')
      end
    end
    if params[:type].nil? || !['order', 'product', 'kit'].include?(params[:type])
      @result['status'] = false
      @result['messages'].push('No Type specified to import')
    end
    if (params[:type] == 'order' && !current_user.can?('import_orders')) ||(['product', 'kit'].include?(params[:type]) && !current_user.can?('import_products'))
      @result['status'] = false
      @result['messages'].push("User does not have permissions to import #{params[:type]}")
    end
  end

  def csv_store_map_data
    csv_map = CsvMapping.find_by_store_id(@store.id)
    if params[:type] =='product'
      params[:name] = csv_map.store.name+' - Default Product Map' if params[:name].blank?
      if csv_map.product_csv_map_id.nil?
        map_data = CsvMap.create(:kind => 'product', :name => params[:name], :map => {})
        csv_map.product_csv_map_id = map_data.id
      else
        map_data = csv_map.product_csv_map
      end
    elsif params[:type] =='kit'
      params[:name] = csv_map.store.name+' - Default Kit Map' if params[:name].blank?
      if csv_map.kit_csv_map_id.nil?
        map_data = CsvMap.create(:kind => 'kit', :name => params[:name], :map => {})
        csv_map.kit_csv_map_id = map_data.id
      else
        map_data = csv_map.kit_csv_map
      end
    elsif params[:type] == 'order'
      params[:name] = csv_map.store.name+' - Default Order Map' if params[:name].blank?
      if csv_map.order_csv_map_id.nil?
        map_data = CsvMap.create(:kind => 'order', :name => params[:name], :map => {})
        csv_map.order_csv_map_id = map_data.id
      else
        map_data = csv_map.order_csv_map
      end
    end
    
    map_data.name = params[:name]
    map_data.map = { :rows => params[:rows], :sep => params[:sep], :other_sep => params[:other_sep], :delimiter => params[:delimiter], :fix_width => params[:fix_width], :fixed_width => params[:fixed_width], :import_action => params[:import_action], :contains_unique_order_items => params[:contains_unique_order_items], :generate_barcode_from_sku => params[:generate_barcode_from_sku], :use_sku_as_product_name => params[:use_sku_as_product_name], :order_date_time_format => params[:order_date_time_format], :day_month_sequence => params[:day_month_sequence], :map => params[:map] }
    begin
      map_data.save!
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
      mapping = CsvMapping.find_or_create_by_store_id(params[:id])
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
      mapping = CsvMapping.find_or_create_by_store_id(params[:id])
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
    ftp.assign_attributes(host: params[:host], username: params[:username], password: params[:password], connection_method: params[:connection_method], connection_established: false, use_ftp_import: params[:use_ftp_import])
    store.ftp_credential = ftp
    begin
      store.save!
      store.ftp_credential.save if !new_record
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
    when "BigCommerce"
      handler = Groovepacker::Stores::Handlers::BigCommerceHandler.new(@store)
    when "Magento API 2"
      handler = Groovepacker::Stores::Handlers::MagentoRestHandler.new(@store)
    when "Shopify"
      handler = Groovepacker::Stores::Handlers::ShopifyHandler.new(@store)
    when "Teapplix"
      handler = Groovepacker::Stores::Handlers::TeapplixHandler.new(@store)
    end
    context = Groovepacker::Stores::Context.new(handler)
    context
  end

  def cancel_product_import 
    result = {"status"=>true, "success_messages"=>[], "notice_messages"=>[], "error_messages"=>[]}
    if params[:id].nil?
      result['status'] = false
      result['error_messages'].push('No id given. Can not cancel product import')
    else
      product_import = CsvProductImport.find_by_id(params[:id])
      product_import.cancel = true
      unless product_import.status == 'in_progress'
        product_import.status = 'cancelled'
        Delayed::Job.find(product_import.delayed_job_id).destroy rescue nil
      end
      result['notice_messages'].push('Product Import marked for cancellation. Please wait for acknowledgement.') if product_import.save
    end
    result
  end

  def push_pull_inventory(flag)
    @store = Store.find(params[:id])
    @result = {"status"=>true}
    @result['status'] = true
    tenant = Apartment::Tenant.current
    import_orders_obj = ImportOrders.new
    import_orders_obj.delay(:run_at => 1.seconds.from_now).init_import(tenant)
    if @store && current_user.can?('update_inventories')
      context = create_handler
      if flag == "push"
        context.delay(:run_at => 1.seconds.from_now).push_inventory
      elsif flag == "pull"
        context.delay(:run_at => 1.seconds.from_now).pull_inventory
        @result['message'] = "Your request for innventory pull has beed queued"
      end
    else
      @result['status'] = false
      flag == "push" ? @result['message'] = "Either the store is not present or you don't have permissions to update inventories." : @result['message'] = "Either the the BigCommerce store is not setup properly or you don't have permissions to update inventories."
    end
  end
end