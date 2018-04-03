module StoresHelper
  def get_default_warehouse_id
    warehouse_name_or_id("id")
    # inventory_warehouses = InventoryWarehouse.where(:is_default => 1)
    # if !inventory_warehouses.nil?
    #   inventory_warehouse = inventory_warehouses.first
    #   default_warehouse_id = inventory_warehouse.id
    #   default_warehouse_id
    # end
  end

  def get_default_warehouse_name
    warehouse_name_or_id("name")
    # inventory_warehouses = InventoryWarehouse.where(:is_default => 1)
    # if !inventory_warehouses.nil?
    #   inventory_warehouse = inventory_warehouses.first
    #   default_warehouse_name = inventory_warehouse.name
    #   default_warehouse_name
    # end
  end

  def warehouse_name_or_id(flag)
    inventory_warehouses = InventoryWarehouse.where(:is_default => 1)
    if !inventory_warehouses.nil?
      inventory_warehouse = inventory_warehouses.first
      if flag == "id"
        default_warehouse_id = inventory_warehouse.id
        return default_warehouse_id
      elsif flag == "name"
        default_warehouse_name = inventory_warehouse.name
        return default_warehouse_name
      end
    end
  end

  def init_store_data
    params[:name]=nil if params[:name]=='undefined'
    @store.name = params[:name] || get_default_warehouse_name
    @store.store_type = params[:store_type]
    @store.status = params[:status]
    @store.thank_you_message_to_customer = params[:thank_you_message_to_customer] unless params[:thank_you_message_to_customer] == 'null'
    @store.inventory_warehouse_id = params[:inventory_warehouse_id] || get_default_warehouse_id
    @store.auto_update_products = params[:auto_update_products]
    @store.on_demand_import = params[:on_demand_import]
    @store.update_inv = params[:update_inv]
    @store.save
  end

  def store_duplicate
    @result = {"status"=>true, "messages"=>[]}
    if current_user.can? 'add_edit_stores'
      params['_json'].each do |store|
        if Store.can_create_new?
          @store = Store.find(store["id"])
          @newstore = @store.dup
          index = 0
          @newstore.name = @store.name+"(duplicate"+index.to_s+")"
          @storeslist = Store.where(:name => @newstore.name)
          begin
            index = index + 1
            @newstore.name = @store.name+"(duplicate"+index.to_s+")"
            @storeslist = Store.where(:name => @newstore.name)
          end while (!@storeslist.nil? && @storeslist.length > 0)
          if !@newstore.save(:validate => false) || !@newstore.dupauthentications(@store.id)
            @result['status'] = false
            @result['messages'] = @newstore.errors.full_messages
          end
        else
          @result['status'] = false
          @result['messages'] = "You have reached the maximum limit of number of stores for your subscription."
        end
      end
    else
      @result["status"] = false
      @result["messages"].push("User does not have permissions to duplicate store")
    end
  end

  def store_delete
    @result = {"status"=>false, "messages"=>[]}
    if current_user.can? 'add_edit_stores'
      system_store_id = Store.find_by_store_type('system').id.to_s
      params['_json'].each do |store|
        @store = Store.where(id: store["id"]).first
        unless @store.nil?
          Product.update_all('store_id = '+system_store_id, 'store_id ='+@store.id.to_s)
          Order.update_all('store_id = '+system_store_id, 'store_id ='+@store.id.to_s)
          destroy_csv_store
          # if @store.store_type == 'CSV'
          #   csv_mapping = CsvMapping.find_by_store_id(@store.id)
          #   csv_mapping.destroy unless csv_mapping.nil?
          #   ftp_credential = FtpCredential.find_by_store_id(@store.id)
          #   ftp_credential.destroy unless ftp_credential.nil?
          # end
          # @result['status'] = true if @store.deleteauthentications && @store.destroy
        end
      end
    else
      @result["status"] = false
      @result["messages"].push("User does not have permissions to delete store")
    end
  end

  def destroy_csv_store
    if @store.store_type == 'CSV'
      csv_mapping = CsvMapping.find_by_store_id(@store.id)
      csv_mapping.destroy unless csv_mapping.nil?
      ftp_credential = FtpCredential.find_by_store_id(@store.id)
      ftp_credential.destroy unless ftp_credential.nil?
    end
    @result['status'] = true if @store.deleteauthentications && @store.destroy
  end

  def show_store
    if !@store.nil? then
      @result['status'] = true
      @result['store'] = @store
      access_restrictions = AccessRestriction.last
      @result['general_settings'] = GeneralSetting.first
      @result['current_tenant'] = Apartment::Tenant.current
      @result['host_url'] = get_host_url
      @result['access_restrictions'] = access_restrictions
      @result['credentials'] = @store.get_store_credentials
      @result['mapping'] = CsvMapping.find_by_store_id(@store.id) if @store.store_type == 'CSV'
    else
      @result['status'] = false
    end
  end

  def get_system_store
    if @store.nil?
      @result['status'] = false
    else
      @result['status'] = true
      @result['store'] = @store
    end
  end

  def check_include_pro_or_shipping_label(flag)
    shippingeasy_cred = ShippingEasyCredential.find_by_store_id(params["store_id"])
    result = {}
    if flag == "update_include_product"
      shippingeasy_cred.includes_product = !shippingeasy_cred.includes_product
      shippingeasy_cred.save
      result["includes_product"] = shippingeasy_cred.includes_product
    elsif flag == "popup_shipping_label"
      shippingeasy_cred.popup_shipping_label = !shippingeasy_cred.popup_shipping_label
      shippingeasy_cred.save
      result["popup_shipping_label"] = shippingeasy_cred.popup_shipping_label
    end
    result
  end

  def update_store_status
    if current_user.can? 'add_edit_stores'
      params['_json'].each do |store|
        @store = Store.find(store["id"])
        @store.status = store["status"]
        @result['status'] = false if !@store.save
      end
      OrderImportSummary.first.emit_data_to_user unless OrderImportSummary.first.nil?
    else
      @result["status"] = false
      @result["messages"].push('User does not have permissions to change store status')
    end
  end

  # def product_csv_import(data)
  #   product_import = CsvProductImport.find_by_store_id(@store.id)
  #   product_import = CsvProductImport.create(store_id: @store.id) if product_import.nil?
  #   import_csv = ImportCsv.new
  #   delayed_job = import_csv.delay(:run_at => 1.seconds.from_now).import Apartment::Tenant.current, data.to_s
  #   product_import.update_attributes(delayed_job_id: delayed_job.id, total: 0, success: 0, cancel: false, status: 'scheduled')
  # end

  def csv_import
    data = {
      flag: params[:flag],
      type: params[:type],
      fix_width: params[:fix_width],
      fixed_width: params[:fixed_width],
      sep: params[:sep],
      delimiter: params[:delimiter],
      rows: params[:rows],
      map: params[:map],
      store_id: params[:store_id],
      user_id: current_user.id,
      import_action: params[:import_action],
      contains_unique_order_items: params[:contains_unique_order_items],
      generate_barcode_from_sku: params[:generate_barcode_from_sku],
      use_sku_as_product_name: params[:use_sku_as_product_name],
      order_placed_at: params[:order_placed_at],
      order_date_time_format: params[:order_date_time_format],
      day_month_sequence: params[:day_month_sequence],
      reimport_from_scratch: params[:reimport_from_scratch]
    }    
    # Comment everything after this line till next comment (i.e. the entire if block) when everything is moved to bulk actions
    if params[:type] == 'order'
      order_csv_import(data)
      # if OrderImportSummary.where(status: 'in_progress').empty? 
      #   bulk_actions = Groovepacker::Orders::BulkActions.new
      #   bulk_actions.delay(:run_at => 1.seconds.from_now).import_csv_orders(Apartment::Tenant.current_tenant, @store.id, data.to_s, current_user.id)
      #   # bulk_actions.import_csv_orders(Apartment::Tenant.current_tenant, @store.id, data.to_s, current_user.id)
      # else
      #   @result['status'] = false
      #   @result['messages'].push("Import is in progress. Try after it is complete")
      # end
    elsif params[:type] == 'kit'
      groove_bulk_actions = GrooveBulkActions.new(:identifier=>'csv_import', :activity=>'kit')
      # groove_bulk_actions.identifier = 'csv_import'
      # groove_bulk_actions.activity = 'kit'
      groove_bulk_actions.save
      data[:bulk_action_id] = groove_bulk_actions.id
      import_csv = ImportCsv.new
      import_csv.delay(:run_at => 1.seconds.from_now).import Apartment::Tenant.current, data.to_s
      # import_csv.import(Apartment::Tenant.current, data.to_s)
    elsif params[:type] == 'product'
      product_import = CsvProductImport.find_by_store_id(@store.id)
      product_import = CsvProductImport.create(store_id: @store.id) if product_import.nil?
      # if product_import.nil?
      #   product_import = CsvProductImport.new
      #   product_import.store_id = @store.id
      #   product_import.save
      # end
      import_csv = ImportCsv.new
      delayed_job = import_csv.delay(:run_at => 1.seconds.from_now).import Apartment::Tenant.current, data.to_s
      # delayed_job = import_csv.import(Apartment::Tenant.current, data.to_s)
      product_import.update_attributes(delayed_job_id: delayed_job.id, total: 0, success: 0, cancel: false, status: 'scheduled')
    end
    # Comment everything before this line till previous comment (i.e. the entire if block) when everything is moved to bulk actions
  end

  def order_csv_import(data)
    if OrderImportSummary.where(status: 'in_progress').empty? 
      bulk_actions = Groovepacker::Orders::BulkActions.new
      bulk_actions.delay(:run_at => 1.seconds.from_now).import_csv_orders(Apartment::Tenant.current_tenant, @store.id, data.to_s, current_user.id)
      # bulk_actions.import_csv_orders(Apartment::Tenant.current_tenant, @store.id, data.to_s, current_user.id)
    else
      @result['status'] = false
      @result['messages'].push("Import is in progress. Try after it is complete")
    end
  end

  def ebay_token_update(url)
    @store = @store.first
    req = Net::HTTP::Post.new(url.path)
    req.add_field("X-EBAY-API-REQUEST-CONTENT-TYPE", 'text/xml')
    req.add_field("X-EBAY-API-COMPATIBILITY-LEVEL", "675")
    req.add_field("X-EBAY-API-DEV-NAME", ENV['EBAY_DEV_ID'])
    req.add_field("X-EBAY-API-APP-NAME", ENV['EBAY_APP_ID'])
    req.add_field("X-EBAY-API-CERT-NAME", ENV['EBAY_CERT_ID'])
    req.add_field("X-EBAY-API-SITEID", 0)
    req.add_field("X-EBAY-API-CALL-NAME", "FetchToken")
    req.body ='<?xml version="1.0" encoding="utf-8"?>'+ '<FetchTokenRequest xmlns="urn:ebay:apis:eBLBaseComponents">'+ '<SessionID>'+session[:ebay_session_id]+'</SessionID>' + '</FetchTokenRequest>'
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    res = http.start do |http_runner|
      http_runner.request(req)
    end
    ebaytoken_resp = MultiXml.parse(res.body)
    @result['response'] = ebaytoken_resp
    if ebaytoken_resp['FetchTokenResponse']['Ack'] == 'Success'
      @store.auth_token = ebaytoken_resp['FetchTokenResponse']['eBayAuthToken']
      @store.productauth_token = ebaytoken_resp['FetchTokenResponse']['eBayAuthToken']
      @store.ebay_auth_expiration = ebaytoken_resp['FetchTokenResponse']['HardExpirationTime']
      @result['status'] = true if @store.save
    end
  end

  def store_list_update
    @store = Store.find(params[:id])
    if @store.nil?
      @result['status'] = false
      @result['message'] = "Either the store is not present or you don't have permissions to update"
    else
      unless params[:var].eql?('status')
        @result['status'] = false
        @result['message'] = "Unkown Field"
        return @result
      end
      @store.status = params[:value] if params[:var] == 'status'
      if @result['status'] && !@store.save
        @result['status'] = false
        @result['message'] = "Could not save store info"
      end
    end
  end

  def create_store
    if params[:id].nil?
      if Store.can_create_new?
        @store = Store.new
        init_store_data
        # GeneralSetting.last.update_attribute(:hex_barcode, true) if params["store_type"] == "Shipstation API 2" rescue nil
        # init_update_store_data
        # ftp_credential = FtpCredential.create(use_ftp_import: false, store_id: @store.id) if params[:store_type] == 'CSV'
        params[:id] = @store.id
      else
        @result['status'] = false
        @result['messages'] = "You have reached the maximum limit of number of stores for your subscription."
      end
    end
    update_create_store unless params[:id].blank?
  end

  def update_create_store
    @store ||= Store.find(params[:id])
    FtpCredential.create(use_ftp_import: false, store_id: @store.id) if params[:store_type] == 'CSV' && @store.ftp_credential.nil?
    create_and_update_store
    @result["store_id"] = @store.id if !@store.nil? && @store.id.present? rescue nil
  end

  def create_and_update_store
    if params[:store_type].nil?
      @result['status'] = false
      @result['messages'].push('Please select a store type to create a store')
    else
      init_store_data
      # init_update_store_data
    end
    if @result['status']
      params[:import_images] = false if params[:import_images].nil?
      params[:import_products] = false if params[:import_products].nil? 
      @result = check_store_type
    else
      @result['status'] = false
      @result['messages'].push("Current user does not have permission to create or edit a store")
    end
  end
end