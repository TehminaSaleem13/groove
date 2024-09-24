# frozen_string_literal: true

class StoresController < ApplicationController
  before_action :groovepacker_authorize!, except: %i[handle_ebay_redirect update_ebay_user_token]
  include StoreConcern

  def index
    @stores = Store.where("store_type != 'system'")
    render json: @stores
  end

  def getactivestores
    @result = { 'status' => true, 'stores' => Store.where("status = '1' AND store_type != 'system'") }
    render json: @result
  end

  def popup_shipping_label
    result = check_include_pro_or_shipping_label('popup_shipping_label')
    render json: result
  end

  def amazon_fba
    result = {}
    store = begin
      Store.find(params['store_id'])
    rescue StandardError
      nil
    end
    store.fba_import = !store.fba_import
    store.save
    result['amazon_fba'] = store.fba_import
    render json: result
  end

  def create_update_ftp_credentials
    result = { 'status' => true, 'messages' => [], 'has_credentials' => false }
    store = Store.find_by_id(params[:id])
    if store.present?
      # store.csv_beta = params['use_csv_beta'] #Enforce CSV Beta by Default
      store.save
    end
    # unless store.nil?
    result = ftp_update(store, result) if store.present? && store.store_type == 'CSV'
    # end
    render json: result
  end

  def ftp_update(store, result)
    update_ftp(store, result)
    # ftp = store.ftp_credential
    # if ftp.nil?
    #   ftp = FtpCredential.new
    #   new_record = true
    # end
    # params[:host] = nil if params[:host] === 'null'
    # ftp.assign_attributes(host: params[:host], username: params[:username], password: params[:password], connection_method: params[:connection_method], connection_established: false, use_ftp_import: params[:use_ftp_import])
    # store.ftp_credential = ftp
    # begin
    #   store.save!
    #   store.ftp_credential.save if !new_record
    # rescue ActiveRecord::RecordInvalid
    #   result['status'] = false
    #   result['messages'] = [store.errors.full_messages, store.ftp_credential.errors.full_messages]
    # rescue ActiveRecord::StatementInvalid => e
    #   result['status'] = false
    #   result['messages'] = [e.message]
    # end
    result
  end

  def get_order_details
    result = {}
    result = get_and_import_order(params, result, current_user)
    render json: result
  end

  def update_store_lro
    result = { status: true }
    begin
      store = Store.find(params['store_id'])
      cred =  store.store_credential
      if cred
        new_lro = Time.zone.parse(DateTime.parse(params['lro_date']).strftime('%Y-%m-%d %H:%M:%S'))
        if store.store_type == 'Shipstation API 2'
          cred.update(quick_import_last_modified_v2: new_lro)
        else
          cred.update(last_imported_at: new_lro)
        end
        cred.track_changes(title: "#{cred.class.name} Changed", tenant: Apartment::Tenant.current,
                           username: current_user.username, object_id: cred.id, changes: { lro: new_lro })
      end
    rescue StandardError => e
      result[:error] = e
      result[:status] = false
    end
    render json: result
  end

  def connect_and_retrieve
    result = {}
    store = Store.find(params[:id])
    groove_ftp = FTP::FtpConnectionManager.get_instance(store, params[:type])
    result[:connection] = groove_ftp.retrieve
    if result[:connection][:status] && params[:type].nil?
      store.ftp_credential.update_attribute(:connection_established,
                                            true)
    end
    if result[:connection][:status] && params[:type] == 'product'
      store.ftp_credential.update_attribute(:product_ftp_connection_established,
                                            true)
    end
    # store.ftp_credential.connection_established = true
    # store.ftp_credential.save!
    render json: result
  end

  # def init_update_store_data
  #   init_store_data
  # end

  def check_imported_folder
    result = {}
    store = Store.find(params[:id])
    groove_ftp = FTP::FtpConnectionManager.get_instance(store, params[:type])
    result[:connection] = groove_ftp.check_imported
    store.ftp_credential.update_attribute(:connection_established, true) if result[:connection][:status]
    render json: result
  end

  def create_update_screct_key_ss
    @result = { 'status' => true, 'store_id' => 0, 'messages' => []}
    create_screct_key_ss if current_user.can? 'add_edit_stores'

    render json: @result
  end

  def create_update_store
    @result = { 'status' => true, 'store_id' => 0, 'csv_import' => false, 'messages' => [] }
    create_store if current_user.can? 'add_edit_stores'
    # if params[:id].nil?
    #   if Store.can_create_new?
    #     @store = Store.new
    #     init_store_data
    #     # init_update_store_data
    #     # ftp_credential = FtpCredential.create(use_ftp_import: false, store_id: @store.id) if params[:store_type] == 'CSV'
    #     params[:id] = @store.id
    #   else
    #     @result['status'] = false
    #     @result['messages'] = "You have reached the maximum limit of number of stores for your subscription."
    #   end
    # end
    # update_create_store unless params[:id].blank?
    # end
    render json: @result
  end

  # def update_create_store
  #   @store ||= Store.find(params[:id])
  #   FtpCredential.create(use_ftp_import: false, store_id: @store.id) if params[:store_type] == 'CSV' && @store.ftp_credential.nil?
  #   create_and_update_store
  #   @result["store_id"] = @store.id if !@store.nil? && @store.id.present? rescue nil
  # end

  # def create_and_update_store
  #   if params[:store_type].nil?
  #     @result['status'] = false
  #     @result['messages'].push('Please select a store type to create a store')
  #   else
  #     init_store_data
  #     # init_update_store_data
  #   end
  #   if @result['status']
  #     params[:import_images] = false if params[:import_images].nil?
  #     params[:import_products] = false if params[:import_products].nil?
  #     @result = check_store_type
  #   else
  #     @result['status'] = false
  #     @result['messages'].push("Current user does not have permission to create or edit a store")
  #   end
  # end

  def save_store(store, store_type, new_record, store_type_credientials)
    store.save!
    store_type.save unless new_record
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.info(e)
    @result['status'] = false
    if store_type_credientials == 'magento_credential'
      @result['messages'] = [store.errors.full_messages, store.magento_credential.errors.full_messages]
    elsif store_type_credientials == 'magento_rest_credential'
      @result['messages'] = [store.errors.full_messages, store.magento_rest_credential.errors.full_messages]
    elsif store_type_credientials == 'amazon_credentials'
      @result['messages'] = [store.errors.full_messages, store.amazon_credentials.errors.full_messages]
    elsif store_type_credientials == 'ebay_credentials'
      @result['messages'] = [store.errors.full_messages, store.ebay_credentials.errors.full_messages]
    elsif store_type_credientials == 'shipstation_credential'
      @result['messages'] = [store.errors.full_messages, store.shipstation_credential.errors.full_messages]
    elsif store_type_credientials == 'shipstation_rest_credential'
      @result['messages'] = [store.errors.full_messages, store.shipstation_rest_credential.errors.full_messages]
    elsif store_type_credientials == 'teapplix_credential'
      @result['messages'] = [store.errors.full_messages, store.teapplix_credential.errors.full_messages]
    end
  rescue ActiveRecord::StatementInvalid => e
    @result['status'] = false
    @result['messages'] = [e.message]
  end

  def csv_map_data
    csv_maps = CsvMap.where(kind: %w[product order kit]).group_by(&:kind)
    render json: { 'product' => csv_maps['product'], 'order' => csv_maps['order'], 'kit' => csv_maps['kit'] }
  end

  def delete_csv_map
    result = { 'status' => true, 'messages' => [] }
    nil_csv_map(result)
    # if params[:kind].nil? || params[:id].nil?
    #   result['status'] = false
    #   result['messages'].push('You need kind and store id to delete csv map')
    # else
    #   mapping = CsvMapping.find_or_create_by_store_id(params[:id])
    #   if params[:kind] == 'order'
    #     mapping.order_csv_map_id = nil
    #   elsif params[:kind] == 'product'
    #     mapping.product_csv_map_id = nil
    #   elsif params[:kind] == 'kit'
    #     mapping.kit_csv_map_id = nil
    #   end
    #   mapping.save
    # end
    render json: result
  end

  def delete_map
    CsvMap.find(params['map']['id']).destroy
    render json: { result: true }
  end

  def update_csv_map
    result = { 'status' => true, 'messages' => [] }
    update_map(result)
    # if params[:map].nil? || params[:id].nil?
    #   result['status'] = false
    #   result['messages'].push('You need map and store id to update csv map')
    # else
    #   mapping = CsvMapping.find_or_create_by_store_id(params[:id])
    #   if params[:map]['kind'] == 'order'
    #     mapping.order_csv_map_id = params[:map]['id']
    #   elsif params[:map]['kind'] == 'product'
    #     mapping.product_csv_map_id = params[:map]['id']
    #   elsif params[:map]['kind'] == 'kit'
    #     mapping.kit_csv_map_id = params[:map]['id']
    #   end
    #   mapping.save
    # end
    render json: result
  end

  def csv_import_data
    data_import
    # @result = {"status"=>true, "messages"=>[]}
    # # general_settings = GeneralSetting.all.first
    # if !params[:id].nil?
    #   @store = Store.find(params[:id])
    # else
    #   @result["status"] = false
    #   @result["messages"].push("No store selected")
    # end
    # csv_data_import if @result["status"]

    render json: @result
  end

  def csv_check_data
    check_store
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

    @result = {}
    result = ImportCsv.new.check_import_file(Apartment::Tenant.current, data)
    message_text = ''
    result.keys.each do |type|
      message_text += if result[type].count > 5
                        result[type].first(5).join('<br>') + '.... and so on.<br>'
                      else
                        result[type].join('<br>')
                      end
      message_text += '<br>' if result[type].present?
    end
    @result[:messages] = message_text
    @result[:status] = !message_text.present?

    render json: @result
  end

  def file_delete(file_path, type)
    return unless File.exist? file_path

    file_data = IO.read(file_path, 40_960)
    if type == 'kit'
      @result['kit']['data'] = file_data
    elsif type == 'order'
      @result['order']['data'] = file_data
    elsif type == 'product'
      @result['product']['data'] = file_data
    end
    File.delete(file_path)
  end

  def csv_do_import
    @result = { 'status' => true, 'last_row' => 0, 'messages' => [] }
    check_store
    check_store_status
    csv_store_map_data if @result['status']
    csv_import if @result['status']
    render json: @result
  end

  def csv_product_import_cancel
    result = cancel_product_import
    # result = {"status"=>true, "success_messages"=>[], "notice_messages"=>[], "error_messages"=>[]}
    # if params[:id].nil?
    #   result['status'] = false
    #   result['error_messages'].push('No id given. Can not cancel product import')
    # else
    #   product_import = CsvProductImport.find_by_id(params[:id])
    #   product_import.cancel = true
    #   unless product_import.status == 'in_progress'
    #     product_import.status = 'cancelled'
    #     Delayed::Job.find(product_import.delayed_job_id).destroy rescue nil
    #   end
    #   result['notice_messages'].push('Product Import marked for cancellation. Please wait for acknowledgement.') if product_import.save
    # end
    render json: result
  end

  def change_store_status
    @result = { 'status' => true, 'messages' => [] }
    update_store_status
    # if current_user.can? 'add_edit_stores'
    #   params['_json'].each do |store|
    #     @store = Store.find(store["id"])
    #     @store.status = store["status"]
    #     @result['status'] = false if !@store.save
    #   end
    #   OrderImportSummary.first.emit_data_to_user unless OrderImportSummary.first.nil?
    # else
    #   @result["status"] = false
    #   @result["messages"].push('User does not have permissions to change store status')
    # end
    render json: @result
  end

  def duplicate_store
    store_duplicate
    render json: @result
  end

  def delete_store
    store_delete
    render json: @result
  end

  def show
    @store = Store.find_by_id(params[:id])
    tenant = Tenant.find_by_name(Apartment::Tenant.current)
    @result = { is_fba: tenant&.is_fba, ss_api_create_label: tenant&.ss_api_create_label,
                product_ftp_import: tenant&.product_ftp_import, order_cup_direct_shipping: tenant&.order_cup_direct_shipping, custom_product_fields: tenant&.custom_product_fields, packing_cam: tenant&.packing_cam }
    show_store
    render json: @result
  end

  def get_system
    @store = Store.find_by_store_type('system')
    @result = {}
    get_system_store
    render json: @result
  end

  def get_ebay_signin_url
    @result = { status: true }
    # @result = Hash.new
    # @result[:status] = true
    @store = Store.new
    @result = @store.get_ebay_signin_url
    # session[:ebay_session_id] = @result['ebay_sessionid']
    $redis.set('ebay_session_id', @result['ebay_sessionid']) if @result['ebay_sessionid'].present?
    @result['current_tenant'] = Apartment::Tenant.current
    render json: @result
  end

  def ebay_user_fetch_token
    require 'net/http'
    require 'uri'
    @result = { 'status' => false }
    # @result = Hash.new
    # devName = ENV['EBAY_DEV_ID']
    # appName = ENV['EBAY_APP_ID']
    # certName = ENV['EBAY_CERT_ID']
    # @result['status'] = false
    ENV['EBAY_SANDBOX_MODE'] == 'YES' ? url = 'https://api.sandbox.ebay.com/ws/api.dll' : url = 'https://api.ebay.com/ws/api.dll'
    url = URI.parse(url)
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
    if ebaytoken_resp['FetchTokenResponse']['Ack'] == 'Success'
      session[:ebay_auth_token] = ebaytoken_resp['FetchTokenResponse']['eBayAuthToken']
      session[:ebay_auth_expiration] = ebaytoken_resp['FetchTokenResponse']['HardExpirationTime']
      @result['status'] = true
    end
    render json: @result
  end

  def update_ebay_user_token
    require 'net/http'
    require 'uri'
    @result = { 'status' => false }
    # devName = ENV['EBAY_DEV_ID']
    # appName = ENV['EBAY_APP_ID']
    # certName = ENV['EBAY_CERT_ID']
    # @result['status'] = false
    url = ENV['EBAY_SANDBOX_MODE'] == 'YES' ? 'https://api.sandbox.ebay.com/ws/api.dll' : 'https://api.ebay.com/ws/api.dll'
    url = URI.parse(url)
    @store = EbayCredentials.where(store_id: params[:id])

    if @store.present?
      ebay_token_update(url)
      # @store = @store.first
      # req = Net::HTTP::Post.new(url.path)
      # req.add_field("X-EBAY-API-REQUEST-CONTENT-TYPE", 'text/xml')
      # req.add_field("X-EBAY-API-COMPATIBILITY-LEVEL", "675")
      # req.add_field("X-EBAY-API-DEV-NAME", ENV['EBAY_DEV_ID'])
      # req.add_field("X-EBAY-API-APP-NAME", ENV['EBAY_APP_ID'])
      # req.add_field("X-EBAY-API-CERT-NAME", ENV['EBAY_CERT_ID'])
      # req.add_field("X-EBAY-API-SITEID", 0)
      # req.add_field("X-EBAY-API-CALL-NAME", "FetchToken")
      # req.body ='<?xml version="1.0" encoding="utf-8"?>'+ '<FetchTokenRequest xmlns="urn:ebay:apis:eBLBaseComponents">'+ '<SessionID>'+session[:ebay_session_id]+'</SessionID>' + '</FetchTokenRequest>'
      # http = Net::HTTP.new(url.host, url.port)
      # http.use_ssl = true
      # res = http.start do |http_runner|
      #   http_runner.request(req)
      # end
      # ebaytoken_resp = MultiXml.parse(res.body)
      # @result['response'] = ebaytoken_resp
      # if ebaytoken_resp['FetchTokenResponse']['Ack'] == 'Success'
      #   @store.auth_token = ebaytoken_resp['FetchTokenResponse']['eBayAuthToken']
      #   @store.productauth_token = ebaytoken_resp['FetchTokenResponse']['eBayAuthToken']
      #   @store.ebay_auth_expiration = ebaytoken_resp['FetchTokenResponse']['HardExpirationTime']
      #   @result['status'] = true if @store.save
      # end
    else
      @result['status'] = false
    end
    respond_to do |format|
      format.html { render layout: 'close_window' }
      format.json { render json: @result }
    end
  end

  def delete_ebay_token
    @result = { 'status' => false }
    if params[:id] == 'undefined'
      session[:ebay_auth_token] = nil
      session[:ebay_auth_expiration] = nil
      @result['status'] = true
    else
      @store = Store.find(params[:id])
      if @store.store_type == 'Ebay'
        @ebaycredentials = EbayCredentials.where(store_id: params[:id])
        @ebaycredentials = @ebaycredentials.first
        @ebaycredentials.auth_token = ''
        @ebaycredentials.productauth_token = ''
        @ebaycredentials.ebay_auth_expiration = ''
        session[:ebay_auth_token] = nil
        session[:ebay_auth_expiration] = nil
        @result['status'] = true if @ebaycredentials.save
      end
    end
    render json: @result
  end

  def handle_ebay_redirect
    # ebaytkn = params['ebaytkn']
    # tknexp = params['tknexp']
    # username = params['username']
    # redirect = params['redirect']
    # editstatus = params['editstatus']
    # name = params['name']
    # status = params['status']
    # storetype = params['storetype']
    storeid = params['storeid']
    # inventorywarehouseid = params['inventorywarehouseid']
    # importimages = params['importimages']
    # importproducts = params['importproducts']
    # messagetocustomer = params['messagetocustomer']
    tenant_name = params['tenantname']
    # redirect_to (URI::encode("https://#{tenant_name}.groovepacker.com:3001//") + "#" + URI::encode("/settings/showstores/ebay?ebaytkn=#{ebaytkn}&tknexp=#{tknexp}&username=#{username}&redirect=#{redirect}&editstatus=#{editstatus}&name=#{name}&status=#{status}&storetype=#{storetype}&storeid=#{storeid}&inventorywarehouseid=#{inventorywarehouseid}&importimages=#{importimages}&importproducts=#{importproducts}&messagetocustomer=#{messagetocustomer}&tenantname=#{tenant_name}") )
    redirect_to CGI.escape("https://#{tenant_name}.#{ENV['SITE_HOST']}/") + CGI.escape("stores/#{storeid}/update_ebay_user_token")
  end

  def let_store_be_created
    render json: { can_create: Store.can_create_new? }
  end

  def verify_tags
    store = Store.find(params[:id])
    result = { status: true, messages: [], data: { verification_result: false, message: '' } }
    if store.store_type == 'Shipstation API 2'
      result[:data] = store.shipstation_rest_credential.verify_tags
    else
      result[:status] = false
      result[:messages] << 'Cannot verify tags for this store'
    end
    render json: result
  end

  def verify_awaiting_tags
    store = Store.find(params[:id])
    result = { status: true, messages: [], data: { verification_result: false, message: '' } }
    if store.store_type == 'Shipstation API 2'
      result[:data] = store.shipstation_rest_credential.verify_awaits_tag
    else
      result[:status] = false
      result[:messages] << 'Cannot verify tags for this store'
    end
    render json: result
  end

  def update_all_locations
    store = Store.find(params[:id])
    result = { status: true, messages: [], data: { update_status: false, message: '' } }
    order_summary = OrderImportSummary.where(status: 'in_progress')
    if order_summary.empty? && store.store_type == 'Shipstation API 2'
      tenant = Apartment::Tenant.current
      Delayed::Job.where(queue: 'importing_orders_' + tenant).destroy_all
      store.shipstation_rest_credential.update_all_locations(tenant, current_user)
    else
      result[:status] = false
      result[:error_messages] << 'Import/Update is in progress'
    end
    render json: result
  end

  def export_active_products
    result = {}
    result['status'] = true
    result['messages'] = []

    products = Product.where(status: 'active')
    if products.empty?
      result['messages'] << 'There are no active products'
    else
      filename = 'groove-products-' + Time.current.to_s + '.csv'
      row_map = {
        SKU: '',
        Name: '',
        WarehouseLocation: '',
        WeightOz: '',
        Category: '',
        Tag1: '',
        Tag2: '',
        Tag3: '',
        Tag4: '',
        Tag5: '',
        CustomsDescription: '',
        CustomsValue: '',
        CustomsTariffNo: '',
        CustomsCountry: '',
        ThumbnailUrl: '',
        UPC: '',
        FillSKU: '',
        Length: '',
        Width: '',
        Height: '',
        UseProductName: '',
        Active: ''
      }

      CSV.open(Rails.root.join('public', 'csv', filename), 'wb') do |csv|
        csv << row_map.keys

        products.each do |product|
          single_row = row_map.dup
          single_row[:SKU] = product.primary_sku
          single_row[:Name] = product.name
          single_row[:WarehouseLocation] = product.primary_warehouse.location_primary
          single_row[:WeightOz] = if product.weight.round == 0
                                    ''
                                  else
                                    product.weight.round.to_s
                                  end
          single_row[:Category] = product.primary_category
          single_row[:Tag1] = ''
          single_row[:Tag2] = ''
          single_row[:Tag3] = ''
          single_row[:Tag4] = ''
          single_row[:Tag5] = ''
          single_row[:CustomsDescription] = ''
          single_row[:CustomsValue] = ''
          single_row[:CustomsTariffNo] = ''
          unless product.order_items.empty? || product.order_items.first.order.nil?
            single_row[:CustomsCountry] =
              product.order_items.first.order.country
          end
          single_row[:ThumbnailUrl] = ''
          single_row[:UPC] = product.primary_barcode
          single_row[:FillSKU] = ''
          single_row[:Length] = ''
          single_row[:Width] = ''
          single_row[:Height] = ''
          single_row[:UseProductName] = ''
          single_row[:Active] = product.is_active

          csv << single_row.values
        end
      end
      public_url = GroovS3.get_csv_export_exception(filename)
    end

    unless result['status']
      CSV.open(Rails.root.join('public', 'csv', filename), 'wb') do |csv|
        csv << result['messages']
      end
      filename = 'error.csv'
      public_url = GroovS3.get_csv_export_exception(filename)
    end

    filename = { url: public_url, filename: }
    render json: filename

    # tenant = Apartment::Tenant.current
    # export_product = ExportSsProductsCsv.new
    # export_product.delay.export_active_products(tenant)
    # result["message"] = "Your export is being processed. It will be emailed to #{GeneralSetting.all.first.email_address_for_packer_notes} when it is ready."
    # render json: result
  end

  def bin_location_api_push
    result = { status: true }
    ExportSsProductsCsv.new.delay(priority: 95).update_ss_product_locations(Apartment::Tenant.current, params[:id])
    render json: result
  end

  def bin_location_api_pull
    result = { status: true }
    ExportSsProductsCsv.new.delay(priority: 95).pull_and_update_ss_product_locations(Apartment::Tenant.current,
                                                                                     params[:id])
    render json: result
  end

  def pull_store_inventory
    push_pull_inventory('pull')
    # @store = Store.find(params[:id])
    # @result = {"status"=>true}
    # # access_restriction = AccessRestriction.last
    # tenant = Apartment::Tenant.current
    # import_orders_obj = ImportOrders.new
    # import_orders_obj.delay(:run_at => 1.seconds.from_now).init_import(tenant)
    # if @store && current_user.can?('update_inventories')
    #   context = create_handler
    #   context.delay(:run_at => 1.seconds.from_now).pull_inventory
    #   #context.pull_inventory
    #   @result['message'] = "Your request for innventory pull has beed queued"
    # else
    #   @result['status'] = false
    #   @result['message'] = "Either the the BigCommerce store is not setup properly or you don't have permissions to update inventories."
    # end
    render json: @result
  end

  def push_store_inventory
    push_pull_inventory('push')
    # @store = Store.find(params[:id])
    # @result = {"status"=>true}
    # @result['status'] = true
    # tenant = Apartment::Tenant.current
    # import_orders_obj = ImportOrders.new
    # import_orders_obj.delay(:run_at => 1.seconds.from_now).init_import(tenant)
    # if @store && current_user.can?('update_inventories')
    #   context = create_handler
    #   context.delay(:run_at => 1.seconds.from_now).push_inventory
    # else
    #   @result['status'] = false
    #   @result['message'] = "Either the store is not present or you don't have permissions to update inventories."
    # end
    render json: @result
  end

  def toggle_shopify_sync
    @store = Store.find(params[:id])
    if @store
      sync_options = SyncOption.joins(product: :store).where(product: { stores: { id: @store.id } })
      sync_options.update_all(sync_with_shopify: params[:type] == 'enable')
    end

    render json: { status: true }
  end

  def toggle_shopline_sync
    @store = Store.find(params[:id])
    if @store
      sync_options = SyncOption.joins(product: :store).where(product: { stores: { id: @store.id } })
      sync_options.update_all(sync_with_shopline: params[:type] == 'enable')
    end

    render json: { status: true }
  end

  def update_store_list
    @result = { 'status' => true }
    store_list_update
    render json: @result
  end

  def update_shopify_token
    @result = { status: true }
    begin
      shopify_credential = Store.find(params[:id]).shopify_credential
      shopify_credential.update(access_token: params[:token])
    rescue StandardError => e
      @result[:status] = false
      @result[:error_messages] = e
    end
    render json: @result
  end

  def update_shopline_token
    @result = { status: true }
    begin
      shopline_credential = Store.find(params[:id]).shopline_credential
      shopline_credential.update(access_token: params[:token])
    rescue StandardError => e
      @result[:status] = false
      @result[:error_messages] = e
    end
    render json: @result
  end

  def fetch_label_related_data
    result = { status: true }
    begin
      order = Order.find(params[:id])
      ss_label_data = order.ss_label_order_data(skip_trying: false, params:)
      result[:ss_label_data] = ss_label_data
    rescue Exception => e
      result[:status] = false
      result[:error] = e
    end
    render json: result
  end
end
