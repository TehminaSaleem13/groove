# frozen_string_literal: true

module StoresHelper
  def get_default_warehouse_id
    warehouse_name_or_id('id')
    # inventory_warehouses = InventoryWarehouse.where(:is_default => 1)
    # if !inventory_warehouses.nil?
    #   inventory_warehouse = inventory_warehouses.first
    #   default_warehouse_id = inventory_warehouse.id
    #   default_warehouse_id
    # end
  end

  def get_default_warehouse_name
    warehouse_name_or_id('name')
    # inventory_warehouses = InventoryWarehouse.where(:is_default => 1)
    # if !inventory_warehouses.nil?
    #   inventory_warehouse = inventory_warehouses.first
    #   default_warehouse_name = inventory_warehouse.name
    #   default_warehouse_name
    # end
  end

  def warehouse_name_or_id(flag)
    inventory_warehouses = InventoryWarehouse.where(is_default: 1)
    return if inventory_warehouses.nil?

    inventory_warehouse = inventory_warehouses.first
    if flag == 'id'
      inventory_warehouse.id

    elsif flag == 'name'
      inventory_warehouse.name

    end
  end

  def init_store_data
    params[:name] = nil if params[:name] == 'undefined'
    return unless params[:status].present?

    @store.name = params[:name] || get_default_warehouse_name
    @store.store_type = params[:store_type]
    @store.status = params[:status]
    unless params[:thank_you_message_to_customer] == 'null'
      @store.thank_you_message_to_customer = params[:thank_you_message_to_customer]
    end
    @store.inventory_warehouse_id = params[:inventory_warehouse_id] || get_default_warehouse_id
    @store.auto_update_products = params[:auto_update_products]
    @store.on_demand_import = params[:on_demand_import].to_boolean
    @store.update_inv = params[:update_inv]
    @store.split_order = params[:split_order]
    @store.on_demand_import_v2 = params[:on_demand_import_v2].to_boolean
    @store.import_user_assignments = params[:import_user_assignments].to_boolean
    @store.regular_import_v2 = params[:regular_import_v2].to_boolean
    @store.quick_fix = params[:quick_fix].to_boolean
    @store.troubleshooter_option = params[:troubleshooter_option].to_boolean
    @store.order_cup_direct_shipping = params[:order_cup_direct_shipping].to_boolean
    @store.display_origin_store_name = params[:display_origin_store_name].to_boolean
    @store.disable_packing_cam = params[:disable_packing_cam].to_boolean
    @store.save
  end

  def store_duplicate
    @result = { 'status' => true, 'messages' => [] }
    if current_user.can? 'add_edit_stores'
      params['_json'].each do |store|
        if Store.can_create_new?
          @store = Store.find(store['id'])
          @newstore = @store.dup
          index = 0
          @newstore.name = @store.name + '(duplicate' + index.to_s + ')'
          @storeslist = Store.where(name: @newstore.name)
          begin
            index += 1
            @newstore.name = @store.name + '(duplicate' + index.to_s + ')'
            @storeslist = Store.where(name: @newstore.name)
          end while (@storeslist.present?)
          if !@newstore.save(validate: false) || !@newstore.dupauthentications(@store.id)
            @result['status'] = false
            @result['messages'] = @newstore.errors.full_messages
          end
        else
          @result['status'] = false
          @result['messages'] = 'You have reached the maximum limit of number of stores for your subscription.'
        end
      end
    else
      @result['status'] = false
      @result['messages'].push('User does not have permissions to duplicate store')
    end
  end

  def store_delete
    @result = { 'status' => false, 'messages' => [] }
    if current_user.can? 'add_edit_stores'
      system_store_id = Store.find_by_store_type('system').id.to_s
      params['_json'].each do |store|
        @store = Store.where(id: store['id']).first
        next if @store.nil?

        Product.update_all(['store_id = ' + system_store_id, 'store_id =' + @store.id.to_s])
        Order.update_all(['store_id = ' + system_store_id, 'store_id =' + @store.id.to_s])
        destroy_csv_store
        # if @store.store_type == 'CSV'
        #   csv_mapping = CsvMapping.find_by_store_id(@store.id)
        #   csv_mapping.destroy unless csv_mapping.nil?
        #   ftp_credential = FtpCredential.find_by_store_id(@store.id)
        #   ftp_credential.destroy unless ftp_credential.nil?
        # end
        # @result['status'] = true if @store.deleteauthentications && @store.destroy
      end
    else
      @result['status'] = false
      @result['messages'].push('User does not have permissions to delete store')
    end
  end

  def destroy_csv_store
    if @store.store_type == 'CSV'
      csv_mapping = CsvMapping.find_by_store_id(@store.id)
      csv_mapping&.destroy
      ftp_credential = FtpCredential.find_by_store_id(@store.id)
      ftp_credential&.destroy
    end
    @result['status'] = true if @store.deleteauthentications && @store.destroy
  end

  def show_store
    if !@store.nil?
      @result['status'] = true
      @result['store'] = @store
      access_restrictions = AccessRestriction.last
      @result['general_settings'] = GeneralSetting.first
      @result['current_tenant'] = Apartment::Tenant.current
      @result['host_url'] = get_host_url
      @result['access_restrictions'] = access_restrictions
      @result['credentials'] = @store.get_store_credentials
      @result['mapping'] = CsvMapping.find_by_store_id(@store.id) if @store.store_type == 'CSV'
      if @store.shipstation_rest_credential.present?
        @result['enabled_status'] =
          @store.shipstation_rest_credential.get_active_statuses.any?
      end
      @result ['show_originating_store_id'] =
        Tenant.find_by(name: Apartment::Tenant.current)&.show_originating_store_id || false
      @result['origin_stores'] = @store.origin_stores
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
    shippingeasy_cred = ShippingEasyCredential.find_by_store_id(params['store_id'])
    result = {}
    if flag == 'popup_shipping_label'
      shippingeasy_cred.popup_shipping_label = !shippingeasy_cred.popup_shipping_label
      shippingeasy_cred.save
      result['popup_shipping_label'] = shippingeasy_cred.popup_shipping_label
    end
    result
  end

  def update_store_status
    if current_user.can? 'add_edit_stores'
      params['_json'].each do |store|
        @store = Store.find(store['id'])
        @store.status = store['status']
        @result['status'] = false unless @store.save
        stop_running_import if @store.status == false
      end
      OrderImportSummary.first&.emit_data_to_user
    else
      @result['status'] = false
      @result['messages'].push('User does not have permissions to change store status')
    end
  end

  # def product_csv_import(data)
  #   product_import = CsvProductImport.find_by_store_id(@store.id)
  #   product_import = CsvProductImport.create(store_id: @store.id) if product_import.nil?
  #   import_csv = ImportCsv.new
  #   delayed_job = import_csv.delay(:run_at => 1.seconds.from_now).import Apartment::Tenant.current, data.to_s
  #   product_import.update(delayed_job_id: delayed_job.id, total: 0, success: 0, cancel: false, status: 'scheduled')
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
      groove_bulk_actions = GrooveBulkActions.new(identifier: 'csv_import', activity: 'kit')
      # groove_bulk_actions.identifier = 'csv_import'
      # groove_bulk_actions.activity = 'kit'
      groove_bulk_actions.save
      data[:bulk_action_id] = groove_bulk_actions.id
      import_csv = ImportCsv.new
      import_csv.delay(run_at: 1.second.from_now, queue: "import_kit_from_csv#{Apartment::Tenant.current}", priority: 95).import Apartment::Tenant.current,
                                                                                                                                 data.to_s
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
      delayed_job = import_csv.delay(run_at: 1.second.from_now, queue: "import_products_from_csv#{Apartment::Tenant.current}", priority: 95).import Apartment::Tenant.current,
                                                                                                                                                    data.to_s
      # delayed_job = import_csv.import(Apartment::Tenant.current, data.to_s)
      product_import.update(delayed_job_id: delayed_job.id, total: 0, success: 0, cancel: false, status: 'scheduled')
    end
    # Comment everything before this line till previous comment (i.e. the entire if block) when everything is moved to bulk actions
  end

  def order_csv_import(data)
    if OrderImportSummary.where(status: 'in_progress').empty?
      bulk_actions = Groovepacker::Orders::BulkActions.new
      bulk_actions.delay(run_at: 1.second.from_now, queue: 'import_csv_orders', priority: 95).import_csv_orders(
        Apartment::Tenant.current, @store.id, data.to_s, current_user.id
      )
      # bulk_actions.import_csv_orders(Apartment::Tenant.current_tenant, @store.id, data.to_s, current_user.id)
    else
      @result['status'] = false
      @result['messages'].push('Import is in progress. Try after it is complete')
    end
  end

  def ebay_token_update(url)
    @store = @store.first
    req = Net::HTTP::Post.new(url.path)
    req.add_field('X-EBAY-API-REQUEST-CONTENT-TYPE', 'text/xml')
    req.add_field('X-EBAY-API-COMPATIBILITY-LEVEL', '675')
    req.add_field('X-EBAY-API-DEV-NAME', ENV['EBAY_DEV_ID'])
    req.add_field('X-EBAY-API-APP-NAME', ENV['EBAY_APP_ID'])
    req.add_field('X-EBAY-API-CERT-NAME', ENV['EBAY_CERT_ID'])
    req.add_field('X-EBAY-API-SITEID', 0)
    req.add_field('X-EBAY-API-CALL-NAME', 'FetchToken')
    req.body = '<?xml version="1.0" encoding="utf-8"?>' + '<FetchTokenRequest xmlns="urn:ebay:apis:eBLBaseComponents">' + "<SessionID>#{$redis.get('ebay_session_id')}</SessionID>" + '</FetchTokenRequest>'
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    res = http.start do |http_runner|
      http_runner.request(req)
    end
    ebaytoken_resp = MultiXml.parse(res.body)
    @result['response'] = ebaytoken_resp
    return unless ebaytoken_resp['FetchTokenResponse']['Ack'] == 'Success'

    @store.auth_token = ebaytoken_resp['FetchTokenResponse']['eBayAuthToken']
    @store.productauth_token = ebaytoken_resp['FetchTokenResponse']['eBayAuthToken']
    @store.ebay_auth_expiration = ebaytoken_resp['FetchTokenResponse']['HardExpirationTime']
    @result['status'] = true if @store.save
  end

  def store_list_update
    @store = Store.find(params[:id])
    if @store.nil?
      @result['status'] = false
      @result['message'] = "Either the store is not present or you don't have permissions to update"
    else
      unless params[:var].eql?('status')
        @result['status'] = false
        @result['message'] = 'Unkown Field'
        return @result
      end
      @store.status = params[:value] if params[:var] == 'status'
      if @result['status'] && !@store.save
        @result['status'] = false
        @result['message'] = 'Could not save store info'
      end
      stop_running_import if @store.status == false
    end
  end

  def create_screct_key_ss
    @store = Store.find(params[:id])
    if params[:id].present? && params[:create].to_boolean
      gen_key = SecureRandom.hex(10)
      @store.shipstation_rest_credential.update(webhook_secret: gen_key)
      @result['message'] = 'Successfully Created'
    else
      @store.shipstation_rest_credential.update(webhook_secret: "")
      @result['message'] = 'Successfully Deleted'
    end
    @result['store_id'] = @store.id
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
        @result['messages'] = 'You have reached the maximum limit of number of stores for your subscription.'
      end
    end
    update_create_store if params[:id].present?
  end

  def update_create_store
    @store ||= Store.find(params[:id])
    if params[:store_type] == 'CSV' && @store.ftp_credential.nil?
      FtpCredential.create(use_ftp_import: false,
                           store_id: @store.id)
    end
    create_and_update_store
    begin
      @result['store_id'] = @store.id if !@store.nil? && @store.id.present?
    rescue StandardError
      nil
    end
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
      @result['messages'].push('Current user does not have permission to create or edit a store')
    end
  end

  def stop_running_import
    return unless OrderImportSummary.last

    OrderImportSummary.last.import_items.each do |import_item|
      import_item.update(status: 'cancelled') if import_item.store_id == @store.id
    end
    import_summary_status = OrderImportSummary.last.import_items.map(&:status).uniq
    return unless import_summary_status.count == 1 && import_summary_status.include?('cancelled')

    OrderImportSummary.last.update(status: 'cancelled')
  end

  def get_and_import_order(params, result, current_user)
    same_order_found = false
    store = Store.find(params[:store_id])
    if store.present?
      result = { store_id: store.id, order_no: params[:order_no] }
      if store.store_type == 'ShippingEasy'
        credential = store.shipping_easy_credential
        client = Groovepacker::ShippingEasy::Client.new(credential)
        response = client.get_single_order(params[:order_no])
        return result[:status] = false if response['orders'].nil? || response['orders'].blank?

        result[:status] = true
        result_modifyDate = Time.zone.parse(response['orders'].last['updated_at']) + Time.zone.utc_offset
        result_createDate = Time.zone.parse(response['orders'].last['ordered_at']) + Time.zone.utc_offset

        time_zone = GeneralSetting.last.time_zone.to_i
        result_createDate_tz = Time.zone.parse(response['orders'].last['ordered_at']) + time_zone

        result.merge!(createDate: result_createDate_tz, modifyDate: result_modifyDate,
                      orderStatus: response['orders'].last['order_status'].titleize, increment_id: response['orders'].last['external_order_identifier'])

        result.merge!(return_range_dates_hash(store, response['orders'].last['external_order_identifier'],
                                              result_modifyDate, result_createDate))
      elsif store.store_type == 'Shopify'
        credential = store.shopify_credential
        client = Groovepacker::ShopifyRuby::Client.new(credential)
        response = client.get_single_order(params[:order_no])

        return result[:status] = false if response['orders'].nil? || response['orders'].blank?

        result[:status] = true
        result_modifyDate = Time.zone.parse(response['orders'].first['updated_at'])
        result_createDate = Time.zone.parse(response['orders'].first['created_at'])

        # time_zone = GeneralSetting.last.time_zone.to_i
        # result_createDate_tz = Time.zone.parse(response['orders'].first["created_at"]) + time_zone
        # result_createDate_tz = Time.zone.parse(response['orders'].first["created_at"])

        result.merge!(createDate: result_createDate, modifyDate: result_modifyDate,
                      orderStatus: response['orders'].first['fulfillment_status']&.titleize, increment_id: response['orders'].first['name'])
      elsif store.store_type == 'Shopline'
        credential = store.shopline_credential
        client = Groovepacker::ShoplineRuby::Client.new(credential)
        response = client.get_single_order(params[:order_no])

        return result[:status] = false if response['orders'].nil? || response['orders'].blank?

        result[:status] = true
        result_modifyDate = Time.zone.parse(response['orders'].first['updated_at'])
        result_createDate = Time.zone.parse(response['orders'].first['created_at'])

        result.merge!(createDate: result_createDate, modifyDate: result_modifyDate,
                      orderStatus: response['orders'].first['fulfillment_status']&.titleize, increment_id: response['orders'].first['name'])
        result[:ss_similar_order_found] = true if response['orders'].count > 1
      elsif store.store_type == 'Shipstation API 2'
        credential = store.shipstation_rest_credential
        client = Groovepacker::ShipstationRuby::Rest::Client.new(credential.api_key, credential.api_secret)
        response = client.get_order_value(params[:order_no])
        return result[:status] = false if response.nil?

        result[:status] = true
        result_modifyDate = ActiveSupport::TimeZone['Pacific Time (US & Canada)'].parse(response.last['modifyDate']).to_time
        result_createDate = ActiveSupport::TimeZone['Pacific Time (US & Canada)'].parse(response.last['orderDate']).to_time

        # time_zone = GeneralSetting.last.time_zone.to_i
        # result_createDate_tz = ActiveSupport::TimeZone["Pacific Time (US & Canada)"].parse(response.last["orderDate"]).to_time

        result.merge!(createDate: result_createDate, modifyDate: result_modifyDate,
                      orderStatus: response.last['orderStatus'].titleize,
                      gp_ready_status: if response.last['tagIds'].nil?
                                         'No'
                                       else
                                         (response.last['tagIds'].include?(48_826) ? 'Yes' : 'No')
                                       end,
                      increment_id: response.last['orderNumber'])

        result.merge!(return_range_dates_hash(store, response.last['orderNumber'], result_modifyDate,
                                              result_createDate))
      elsif store.store_type == 'Veeqo'
        credential = store.veeqo_credential
        client = Groovepacker::VeeqoRuby::Client.new(credential)
        order_res = client.get_single_order(params[:order_no])
        response = order_res['orders']
        return result[:status] = false if response.empty? || response[0]['error_messages'] == 'Not found'

        result[:status] = true
        result_modifyDate = ActiveSupport::TimeZone['Pacific Time (US & Canada)'].parse(response.last['updated_at']).to_time
        result_createDate = ActiveSupport::TimeZone['Pacific Time (US & Canada)'].parse(response.last['created_at']).to_time
        result.merge!(createDate: result_createDate, modifyDate: result_modifyDate,
                      orderStatus: response.last['status'].titleize, increment_id: response.last['number'])
      elsif store.store_type == 'Shippo'
        credential = store.shippo_credential
        client = Groovepacker::ShippoRuby::Client.new(credential)
        response = client.get_single_order(params[:order_no])

        return result[:status] = false if response.nil? || response.blank?

        result[:status] = true
        result_modifyDate = Time.zone.parse(response['placed_at'])
        result_createDate = Time.zone.parse(response['placed_at'])

        result.merge!(createDate: result_createDate, modifyDate: result_modifyDate,
                      orderStatus: response['order_status']&.titleize, increment_id: response['order_number'])
      end
      result[:ss_similar_order_found] = true if store.store_type != 'Shopline' && response.count > 1
      params[:current_user] = current_user.id
      params[:tenant] = Apartment::Tenant.current
      import_orders = ImportOrders.new.delay(queue: "import_missing_order_#{Apartment::Tenant.current}", priority: 95)
      import_order =  import_orders.import_missing_order(params) unless Order.where(increment_id: params[:order_no]).any?
      import_orders.import_missing_order(params) if params[:same_order_found]
      Groovepacker::Stores::Importers::LogglyLog.log_orders_response(response['orders'], store, import_order) if current_tenant_object&.loggly_shopify_imports

      result[:store_type] = store.store_type
    end
    order_found = Order.where(increment_id: (params[:order_no]).to_s).last
    if order_found.present?
      result[:gp_order_found] = order_found.status
      result[:id] = order_found.id
    end
    result
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
      if store_orders_blank
        credential.last_imported_at.nil? ? 1.day.ago : credential.last_imported_at
      else
        1.day.ago
      end
    end
  end

  def get_time_in_pst(time)
    zone = 'Pacific Time (US & Canada)'
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

    closest_date = Order.select('last_modified').where('store_id = ? AND increment_id != ?', store_id, order_id).where(
      "last_modified #{comparison_operator} ?", altered_date
    ).order("last_modified #{sort_order}").last.try(:last_modified)
    return closest_date if closest_date.present?

    date
  end
end
