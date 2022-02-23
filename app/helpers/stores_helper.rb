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
    if params[:status].present?
      @store.name = params[:name] || get_default_warehouse_name
      @store.store_type = params[:store_type]
      @store.status = params[:status]
      @store.thank_you_message_to_customer = params[:thank_you_message_to_customer] unless params[:thank_you_message_to_customer] == 'null'
      @store.inventory_warehouse_id = params[:inventory_warehouse_id] || get_default_warehouse_id
      @store.auto_update_products = params[:auto_update_products]
      @store.on_demand_import = params[:on_demand_import].to_boolean
      @store.update_inv = params[:update_inv]
      @store.split_order = params[:split_order]
      @store.on_demand_import_v2 = params[:on_demand_import_v2].to_boolean
      @store.regular_import_v2 = params[:regular_import_v2].to_boolean
      @store.quick_fix = params[:quick_fix].to_boolean
      @store.troubleshooter_option = params[:troubleshooter_option].to_boolean
      @store.order_cup_direct_shipping = params[:order_cup_direct_shipping].to_boolean
      @store.save
    end
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
          Product.update_all(['store_id = '+system_store_id, 'store_id ='+@store.id.to_s])
          Order.update_all(['store_id = '+system_store_id, 'store_id ='+@store.id.to_s])
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
      @result['enabled_status'] = @store.shipstation_rest_credential.get_active_statuses.any? if @store.shipstation_rest_credential.present?
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
    if flag == "popup_shipping_label"
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
        stop_running_import if @store.status == false
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
      map: params[:map].to_unsafe_h,
      store_id: params[:store_id],
      user_id: current_user.id,
      import_action: params[:import_action],
      contains_unique_order_items: params[:contains_unique_order_items],
      generate_barcode_from_sku: params[:generate_barcode_from_sku],
      use_sku_as_product_name: params[:use_sku_as_product_name],
      permit_duplicate_barcodes: params[:permit_duplicate_barcodes],
      order_placed_at: params[:order_placed_at],
      order_date_time_format: params[:order_date_time_format],
      day_month_sequence: params[:day_month_sequence],
      reimport_from_scratch: params[:reimport_from_scratch],
      encoding_format: params[:encoding_format]
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
      import_csv.delay(:run_at => 1.seconds.from_now, :queue => "import_kit_from_csv#{Apartment::Tenant.current}", priority: 95).import Apartment::Tenant.current, data.to_s
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
      delayed_job = import_csv.delay(:run_at => 1.seconds.from_now, :queue => "import_products_from_csv#{Apartment::Tenant.current}", priority: 95).import Apartment::Tenant.current, data.to_s
      # delayed_job = import_csv.import(Apartment::Tenant.current, data.to_s)
      product_import.update_attributes(delayed_job_id: delayed_job.id, total: 0, success: 0, cancel: false, status: 'scheduled')
    end
    # Comment everything before this line till previous comment (i.e. the entire if block) when everything is moved to bulk actions
  end

  def order_csv_import(data)
    if OrderImportSummary.where(status: 'in_progress').empty?
      bulk_actions = Groovepacker::Orders::BulkActions.new
      bulk_actions.delay(:run_at => 1.seconds.from_now, :queue => 'import_csv_orders', priority: 95).import_csv_orders(Apartment::Tenant.current, @store.id, data.to_s, current_user.id)
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
    req.body ='<?xml version="1.0" encoding="utf-8"?>'+ '<FetchTokenRequest xmlns="urn:ebay:apis:eBLBaseComponents">'+ "<SessionID>#{$redis.get('ebay_session_id')}</SessionID>" + '</FetchTokenRequest>'
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
      stop_running_import if @store.status == false
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
      stop_running_import if @store.status == false
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

  def stop_running_import
    return unless OrderImportSummary.last
    OrderImportSummary.last.import_items.each do |import_item|
      import_item.update_attributes(status: 'cancelled') if import_item.store_id == @store.id
    end
    import_summary_status = OrderImportSummary.last.import_items.map(&:status).uniq
    OrderImportSummary.last.update_attributes(status: 'cancelled') if import_summary_status.count == 1 && import_summary_status.include?('cancelled')
  end

  def get_and_import_order(params, result, current_user)
    store = Store.find(params[:store_id])
    if store.present?
      result = { store_id: store.id, order_no: params[:order_no] }
      if store.store_type == 'ShippingEasy'
        credential = store.shipping_easy_credential
        client = Groovepacker::ShippingEasy::Client.new(credential)
        response = client.get_single_order(params[:order_no])
        return result[:status] = false if response['orders'].nil? || response['orders'].blank?

        result[:status] = true
        result_modifyDate = Time.zone.parse(response['orders'].last["updated_at"]) + Time.zone.utc_offset
        result_createDate = Time.zone.parse(response['orders'].last["ordered_at"]) + Time.zone.utc_offset

        time_zone = GeneralSetting.last.time_zone.to_i
        result_createDate_tz = Time.zone.parse(response['orders'].last["ordered_at"]) + time_zone

        result.merge!(createDate: result_createDate_tz, modifyDate: result_modifyDate,
          orderStatus: response['orders'].last["order_status"].titleize)

        result.merge!(return_range_dates_hash(store, response['orders'].last["external_order_identifier"], result_modifyDate, result_createDate))
      elsif store.store_type == 'Shopify'
        credential = store.shopify_credential
        client = Groovepacker::ShopifyRuby::Client.new(credential)
        response = client.get_single_order(params[:order_no])

        return result[:status] = false if response['orders'].nil? || response['orders'].blank?

        result[:status] = true
        result_modifyDate = Time.zone.parse(response['orders'].first["updated_at"])
        result_createDate = Time.zone.parse(response['orders'].first["created_at"])

        # time_zone = GeneralSetting.last.time_zone.to_i
        # result_createDate_tz = Time.zone.parse(response['orders'].first["created_at"]) + time_zone
        # result_createDate_tz = Time.zone.parse(response['orders'].first["created_at"])

        result.merge!(createDate: result_createDate, modifyDate: result_modifyDate,
          orderStatus: response['orders'].first["fulfillment_status"]&.titleize)
      elsif store.store_type == 'Shipstation API 2'
        credential = store.shipstation_rest_credential
        client = Groovepacker::ShipstationRuby::Rest::Client.new(credential.api_key, credential.api_secret)
        response = client.get_order_value(params[:order_no])
        return result[:status] = false if response.nil?

        result[:status] = true
        result_modifyDate = ActiveSupport::TimeZone["Pacific Time (US & Canada)"].parse(response.last["modifyDate"]).to_time
        result_createDate = ActiveSupport::TimeZone["Pacific Time (US & Canada)"].parse(response.last["orderDate"]).to_time

        # time_zone = GeneralSetting.last.time_zone.to_i
        # result_createDate_tz = ActiveSupport::TimeZone["Pacific Time (US & Canada)"].parse(response.last["orderDate"]).to_time

        result.merge!(createDate: result_createDate, modifyDate: result_modifyDate,
          orderStatus: response.last["orderStatus"].titleize,
          gp_ready_status: response.last["tagIds"].nil? ? 'No' : (response.last["tagIds"].include?(48826) ?  'Yes' : 'No'))

        result.merge!(return_range_dates_hash(store, response.last["orderNumber"], result_modifyDate, result_createDate))
      end
      params[:current_user] = current_user.id
      params[:tenant] = Apartment::Tenant.current
      ImportOrders.new.delay(queue: "import_missing_order_#{Apartment::Tenant.current}", priority: 95).import_missing_order(params) unless Order.where(increment_id: params[:order_no]).any?
      result[:store_type] = store.store_type
    end
    order_found = Order.where(increment_id: "#{params[:order_no]}").last
    result.merge!(gp_order_found: order_found.status, id: order_found.id) if order_found.present?
    return result
  end

  def return_range_dates_hash(store, order_id, result_modifyDate, result_createDate)
    dates = {}
    credential = store.store_type == 'Shipstation API 2' ? store.shipstation_rest_credential : store.shipping_easy_credential
    result_modifyDate = DateTime.parse(result_modifyDate.to_s)
    result_createDate = DateTime.parse(result_createDate.to_s)
    store_orders = Order.where('store_id = ? AND increment_id != ?', store.id, order_id)
    if store_orders.blank? || store_orders.where('last_modified > ?', result_modifyDate).blank?
      # Rule #1 - If there are no orders in our DB (other than the order provided to the troubleshooter, ie. the QF Order which gets automatically imported) when the QF import is run, then delete the LRO timestamp and run a regular import. - A 24 hour import range will be run rather than the usual QF range.

      # Rule #2- If the OSLMT of the QF order is newer/more recent than that of any OSLMT in DB, then run a regular import
      dates[:range_start_date] = get_start_range_date(store_orders.blank?, store, credential)
      dates[:range_end_date] = store.store_type == 'ShippingEasy' ? Time.current : get_time_in_pst(Time.zone.now)
    elsif store_orders.where('last_modified < ?', result_modifyDate).blank?
      # Rule #3- If the OSLMT of the QF order is Older than any OSLMT saved in our DB , and a more recent order does exist, then start the import range 6 hours before the OSLMT of the QF order and end the range 6 hours after the OSLMT of the QF order. (12 hours with the OSLMT in the middle)
      dates[:range_start_date] = result_modifyDate - 6.hours
      dates[:range_end_date] = result_modifyDate + 6.hours
    else
      dates[:range_start_date] = get_closest_date(store.id, order_id, result_modifyDate, '<')
      dates[:range_end_date] = get_closest_date(store.id, order_id, result_modifyDate, '>')
    end
    dates[:range_created_start_date] = get_time_in_gp(get_closest_date(store.id, order_id, result_createDate, '<'))
    dates[:range_created_end_date] = get_time_in_gp(get_closest_date(store.id, order_id, result_createDate, '>'))
    dates.each_pair { |key, value| dates[key] = value.strftime('%Y-%m-%d %H:%M:%S') }
  end

  def get_start_range_date(store_orders_blank, store, credential)
    if store.store_type == 'Shipstation API 2'
      if store_orders_blank
        get_time_in_pst(1.day.ago)
      else
        # if store.regular_import_v2
        #   !credential.quick_import_last_modified_v2.nil? ? credential.quick_import_last_modified_v2 : get_time_in_pst(1.day.ago)
        # else
        #   !credential.quick_import_last_modified.nil? ? credential.quick_import_last_modified - 8.hours : get_time_in_pst(1.day.ago)
        # end
        !credential.quick_import_last_modified_v2.nil? ? credential.quick_import_last_modified_v2 : get_time_in_pst(1.day.ago)
      end
    elsif store.store_type == 'ShippingEasy'
      store_orders_blank ? (credential.last_imported_at.nil? ? 1.day.ago : credential.last_imported_at) : 1.day.ago
    end
  end

  def get_time_in_pst(time)
    zone = "Pacific Time (US & Canada)"
    pst_time = ActiveSupport::TimeZone[zone].parse(time.to_s)
  end

  def get_time_in_gp(time)
    time = get_time_in_pst(time.strftime('%Y-%m-%d %H:%M:%S')).utc
    time_zone = GeneralSetting.last.time_zone.to_i
    gp_time = (time + time_zone)
  end

  def get_closest_date(store_id, order_id, date, comparison_operator)
    altered_date = comparison_operator == '<' ? date - 1.minute : date + 1.minute
    sort_order = comparison_operator == '<' ? 'asc' : 'desc'

    closest_date = Order.select('last_modified').where('store_id = ? AND increment_id != ?', store_id, order_id).where("last_modified #{comparison_operator} ?", altered_date).order("last_modified #{sort_order}").last.try(:last_modified)
    return closest_date if closest_date.present?
    date
  end
end
