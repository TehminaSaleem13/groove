class StoresController < ApplicationController
  before_filter :groovepacker_authorize!, :except => [:handle_ebay_redirect]
  include StoresHelper

  def index
    @stores = Store.where("store_type != 'system'")

    respond_to do |format|
      format.json { render json: @stores }
    end
  end

  def getactivestores
    @result = Hash.new
    @result['status'] = true
    @result['stores'] = Store.where("status = '1' AND store_type != 'system'")

    respond_to do |format|
      format.json { render json: @result }
    end
  end

  def create_update_ftp_credentials
    result = {}

    result['status'] = true
    result['messages'] =[]
    result['has_credentials'] = false
    store = Store.find_by_id(params[:id])
    unless store.nil?
      if store.store_type == 'CSV'
        ftp = store.ftp_credential
        if ftp.nil?
          ftp = FtpCredential.new
          new_record = true
        end
        params[:host] = nil if params[:host] === 'null'
        ftp.host = params[:host]
        ftp.username = params[:username]
        ftp.password = params[:password]
        ftp.connection_method = params[:connection_method]
        ftp.connection_established = false
        ftp.use_ftp_import = params[:use_ftp_import]
        store.ftp_credential = ftp
        begin
          store.save!
          if !new_record
            store.ftp_credential.save
          end
        rescue ActiveRecord::RecordInvalid => e
          result['status'] = false
          result['messages'] = [store.errors.full_messages, store.ftp_credential.errors.full_messages]

        rescue ActiveRecord::StatementInvalid => e
          result['status'] = false
          result['messages'] = [e.message]
        end
      end
    end

    respond_to do |format|
      format.json { render json: result }
    end
  end

  def connect_and_retrieve
    result = {}
    store = Store.find(params[:id])
    groove_ftp = FTP::FtpConnectionManager.get_instance(store)
    result[:connection] = groove_ftp.retrieve()
    if result[:connection][:status]
      store.ftp_credential.connection_established = true
      store.ftp_credential.save!
    end

    respond_to do |format|
      format.json { render json: result }
    end
  end

  def init_update_store_data(params)
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

  def create_update_store
    @result = Hash.new

    @result['status'] = true
    @result['store_id'] = 0
    @result['csv_import'] = false
    @result['messages'] =[]

    if current_user.can? 'add_edit_stores'
      if params[:id].nil?
        if Store.can_create_new?
          @store = Store.new
          init_update_store_data(params)
          ftp_credential = FtpCredential.create(use_ftp_import: false, store_id: @store.id) if params[:store_type] == 'CSV'
          params[:id] = @store.id
        else
          @result['status'] = false
          @result['messages'] = "You have reached the maximum limit of number of stores for your subscription."
        end
      end

      unless params[:id].blank?
        @store ||= Store.find(params[:id])
        FtpCredential.create(use_ftp_import: false, store_id: @store.id) if params[:store_type] == 'CSV' && @store.ftp_credential.nil?
        if params[:store_type].nil?
          @result['status'] = false
          @result['messages'].push('Please select a store type to create a store')
        else
          init_update_store_data(params)
        end

        if @result['status']
          if params[:import_images].nil?
            params[:import_images] = false
          end
          if params[:import_products].nil?
            params[:import_products] = false
          end
          if @store.store_type == 'Magento'
            @magento = MagentoCredentials.where(:store_id => @store.id)
            if @magento.blank?
              @magento = @store.build_magento_credentials
              new_record = true
            else
              @magento = @magento.first
            end
            host_url = params[:host].sub(/(\/)+$/,'') rescue nil
            @magento.host = host_url
            @magento.username = params[:username]
            # We do not need password GROOV-168
            #@magento.password = params[:password]
            @magento.api_key = params[:api_key]
            @magento.shall_import_processing = params[:shall_import_processing]
            @magento.shall_import_pending = params[:shall_import_pending]
            @magento.shall_import_closed = params[:shall_import_closed]
            @magento.shall_import_complete = params[:shall_import_complete]
            @magento.shall_import_fraud = params[:shall_import_fraud]
            @magento.enable_status_update = params[:enable_status_update]
            @magento.status_to_update = params[:status_to_update]
            @magento.push_tracking_number = params[:push_tracking_number]

            @magento.import_products = params[:import_products]
            @magento.import_images = params[:import_images]
            begin
              @store.save!
              @magento.save if !new_record
            rescue ActiveRecord::RecordInvalid => e
              @result['status'] = false
              @result['messages'] = [@store.errors.full_messages, @store.magento_credentials.errors.full_messages]

            rescue ActiveRecord::StatementInvalid => e
              @result['status'] = false
              @result['messages'] = [e.message]
            end
          end

          if @store.store_type == "Magento API 2"
            @magento_rest = MagentoRestCredential.where(:store_id => @store.id)
            if @magento_rest.blank?
              @magento_rest = @store.build_magento_rest_credential
              new_record = true
            else
              @magento_rest = @magento_rest.first
            end
            not_to_save = ["undefined", "null"]
            host_url = params[:host].sub(/(\/)+$/,'') rescue nil
            @magento_rest.host = not_to_save.include?(params[:host]) ? nil : host_url
            store_admin_url = params[:store_admin_url].sub(/(\/)+$/,'') rescue nil
            @magento_rest.store_admin_url = not_to_save.include?(store_admin_url) ? nil : store_admin_url
            if @magento_rest.store_version != params[:store_version]
              @magento_rest.access_token=nil
              @magento_rest.oauth_token_secret=nil
            end
            @magento_rest.store_version = params[:store_version]
            @magento_rest.store_token = Store.get_sucure_random_token(20).gsub("=","").gsub("/","") if @magento_rest.store_token.blank?
            @magento_rest.api_key = params[:api_key]
            @magento_rest.api_secret = params[:api_secret]

            @magento_rest.import_categories = params[:import_categories]
            @magento_rest.import_images = params[:import_images]
            @magento_rest.gen_barcode_from_sku = params[:gen_barcode_from_sku]
            begin
              @store.save!
              if !new_record
                @magento_rest.save
              end
            rescue ActiveRecord::RecordInvalid => e
              @result['status'] = false
              @result['messages'] = [@store.errors.full_messages, @store.magento_rest_credential.errors.full_messages]

            rescue ActiveRecord::StatementInvalid => e
              @result['status'] = false
              @result['messages'] = [e.message]
            end
          end

          if @store.store_type == 'Amazon'
            @amazon = AmazonCredentials.where(:store_id => @store.id)

            if @amazon.nil? || @amazon.length == 0
              @amazon = AmazonCredentials.new
              new_record = true
            else
              @amazon = @amazon.first
            end
            @amazon.marketplace_id = params[:marketplace_id]
            @amazon.merchant_id = params[:merchant_id]
            @amazon.mws_auth_token = params[:mws_auth_token]

            @amazon.import_products = params[:import_products]
            @amazon.import_images = params[:import_images]
            @amazon.show_shipping_weight_only = params[:show_shipping_weight_only]
            @store.amazon_credentials = @amazon
            begin
              @store.save!
              if !new_record
                @amazon.save
              end
            rescue ActiveRecord::RecordInvalid => e
              @result['status'] = false
              @result['messages'] = [@store.errors.full_messages, @store.amazon_credentials.errors.full_messages]

            rescue ActiveRecord::StatementInvalid => e
              @result['status'] = false
              @result['messages'] = [e.message]
            end
          end

          if @store.store_type == 'Ebay'
            @ebay = EbayCredentials.where(:store_id => @store.id)

            if @ebay.nil? || @ebay.length == 0
              @ebay = EbayCredentials.new
            else
              @ebay = @ebay.first
            end

            @ebay.auth_token = session[:ebay_auth_token] if !session[:ebay_auth_token].nil?
            @ebay.productauth_token = session[:ebay_auth_token] if !session[:ebay_auth_token].nil?
            @ebay.ebay_auth_expiration = session[:ebay_auth_expiration]
            @ebay.import_products = params[:import_products]
            @ebay.import_images = params[:import_images]

            @store.ebay_credentials = @ebay

            begin
              @store.save!
              if !new_record
                @ebay.save
              end
            rescue ActiveRecord::RecordInvalid => e
              @result['status'] = false
              @result['messages'] = [@store.errors.full_messages, @store.ebay_credentials.errors.full_messages]

            rescue ActiveRecord::StatementInvalid => e
              @result['status'] = false
              @result['messages'] = [e.message]
            end
            @result['store_id'] = @store.id
            @result['tenant_name'] = Apartment::Tenant.current
          end

          if @store.store_type == 'CSV' || @store.store_type == 'system'
            begin
              @store.save!
            rescue ActiveRecord::RecordInvalid => e
              @result['status'] = false
              @result['messages'] = [@store.errors.full_messages]

            rescue ActiveRecord::StatementInvalid => e
              @result['status'] = false
              @result['messages'] = [e.message]
            end

            if @store.id
              @result["store_id"] = @store.id
              csv_directory = "uploads/csv"
              current_tenant = Apartment::Tenant.current
              unless params[:orderfile].nil?
                path = File.join(csv_directory, "#{current_tenant}.#{@store.id}.order.csv")
                order_file_data = params[:orderfile].read
                File.open(path, "wb") { |f| f.write(order_file_data) }
                GroovS3.create_order_csv(current_tenant, 'order', @store.id, order_file_data)
                @result['csv_import'] = true
              end
              unless params[:productfile].nil?
                path = File.join(csv_directory, "#{current_tenant}.#{@store.id}.product.csv")
                product_file_data = params[:productfile].read
                File.open(path, "wb") { |f| f.write(product_file_data) }

                GroovS3.create_csv(current_tenant, 'product', @store.id, product_file_data)
                @result['csv_import'] = true
              end
              unless params[:kitfile].nil?
                path = File.join(csv_directory, "#{current_tenant}.#{@store.id}.kit.csv")
                kit_file_data = params[:kitfile]
                File.open(path, "wb") { |f| f.write(kit_file_data) }

                GroovS3.create_csv(current_tenant, 'kit', @store.id, kit_file_data)
                @result['csv_import'] = true
              end
            end
          end
          if @store.store_type == 'Shipstation'
            @shipstation = ShipstationCredential.where(:store_id => @store.id)
            if @shipstation.nil? || @shipstation.length == 0
              @shipstation = ShipstationCredential.new
              new_record = true
            else
              @shipstation = @shipstation.first
            end

            @shipstation.username = params[:username]
            @shipstation.password = params[:password]
            @store.shipstation_credential = @shipstation

            begin
              @store.save!
              if !new_record
                @shipstation.save
              end
            rescue ActiveRecord::RecordInvalid => e
              @result['status'] = false
              @result['messages'] = [@store.errors.full_messages, @store.shipstation_credential.errors.full_messages]

            rescue ActiveRecord::StatementInvalid => e
              @result['status'] = false
              @result['messages'] = [e.message]
            end
          end

          if @store.store_type == 'Shipstation API 2'
            @shipstation = ShipstationRestCredential.where(:store_id => @store.id)
            if @shipstation.nil? || @shipstation.length == 0
              @shipstation = ShipstationRestCredential.new
              new_record = true
            else
              @shipstation = @shipstation.first
            end

            @shipstation.api_key = params[:api_key]
            @shipstation.api_secret = params[:api_secret]
            @shipstation.shall_import_awaiting_shipment = params[:shall_import_awaiting_shipment]
            @shipstation.shall_import_shipped = params[:shall_import_shipped]
            @shipstation.shall_import_pending_fulfillment = params[:shall_import_pending_fulfillment]
            @shipstation.warehouse_location_update = params[:warehouse_location_update]
            @shipstation.shall_import_customer_notes = params[:shall_import_customer_notes]
            @shipstation.shall_import_internal_notes = params[:shall_import_internal_notes]
            @shipstation.regular_import_range = params[:regular_import_range] unless params[:regular_import_range].nil?
            @shipstation.gen_barcode_from_sku = params[:gen_barcode_from_sku]
            @store.shipstation_rest_credential = @shipstation

            begin
              @store.save!
              if !new_record
                @shipstation.save
              end
            rescue ActiveRecord::RecordInvalid => e
              @result['status'] = false
              @result['messages'] = [@store.errors.full_messages, @store.shipstation_rest_credential.errors.full_messages]

            rescue ActiveRecord::StatementInvalid => e
              @result['status'] = false
              @result['messages'] = [e.message]
            end
          end
          if @store.store_type == 'ShippingEasy'
            @shippingeasy = @store.shipping_easy_credential || @store.create_shipping_easy_credential
            new_record = true unless @shippingeasy.persisted?

            @shippingeasy.attributes = {  api_key: params[:api_key],
                                          api_secret: params[:api_secret],
                                          import_ready_for_shipment: params[:import_ready_for_shipment],
                                          import_shipped: params[:import_shipped],
                                          gen_barcode_from_sku: params[:gen_barcode_from_sku]
                                        }
            @shippingeasy.save
            begin
              @store.save!
            rescue ActiveRecord::RecordInvalid => e
              @result['status'] = false
              @result['messages'] = [@store.errors.full_messages, @store.shipping_easy_credential.errors.full_messages]
            rescue ActiveRecord::StatementInvalid => e
              @result['status'] = false
              @result['messages'] = [e.message]
            end
          end

          if @store.store_type == 'Shipworks'
            @shipworks = ShipworksCredential.find_by_store_id(@store.id)
            begin
              if @shipworks.nil?
                @store.shipworks_credential = ShipworksCredential.new(
                  auth_token: Store.get_sucure_random_token,
                  import_store_order_number: params[:import_store_order_number],
                  shall_import_in_process: params[:shall_import_in_process],
                  shall_import_new_order: params[:shall_import_new_order],
                  shall_import_not_shipped: params[:shall_import_not_shipped],
                  shall_import_shipped: params[:shall_import_shipped],
                  shall_import_no_status: params[:shall_import_no_status],
                  gen_barcode_from_sku: params[:gen_barcode_from_sku])
                new_record = true
              else
                @shipworks.update_attributes(
                  import_store_order_number: params[:import_store_order_number],
                  shall_import_in_process: params[:shall_import_in_process],
                  shall_import_new_order: params[:shall_import_new_order],
                  shall_import_not_shipped: params[:shall_import_not_shipped],
                  shall_import_shipped: params[:shall_import_shipped],
                  shall_import_no_status: params[:shall_import_no_status],
                  gen_barcode_from_sku: params[:gen_barcode_from_sku])
              end
              @store.save
            rescue ActiveRecord::RecordInvalid => e
              @result['status'] = false
              @result['messages'] = [@store.errors.full_messages, @store.shipstation_credential.errors.full_messages]

            rescue ActiveRecord::StatementInvalid => e
              @result['status'] = false
              @result['messages'] = [e.message]
            end
          end

          if @store.store_type == 'Shopify'
            @shopify = ShopifyCredential.find_by_store_id(@store.id)
            begin
              params[:shop_name] = nil if params[:shop_name] == 'null'
              if @shopify.nil?
                @store.shopify_credential = ShopifyCredential.new(
                  shop_name: params[:shop_name])
                new_record = true
              else
                @shopify.update_attributes(shop_name: params[:shop_name])
              end
              @store.save
            rescue ActiveRecord::RecordInvalid => e
              @result['status'] = false
              @result['messages'] = [@store.errors.full_messages,
                                     @store.shopify_credential.errors.full_messages]

            rescue ActiveRecord::StatementInvalid => e
              @result['status'] = false
              @result['messages'] = [e.message]
            end
            current_tenant = Apartment::Tenant.current
            cookies[:tenant_name] = {:value => current_tenant , :domain => :all, :expires => Time.now+10.minutes}
            cookies[:store_id] = {:value => @store.id , :domain => :all, :expires => Time.now+10.minutes}
          end
          if @store.store_type == 'BigCommerce'
            @bigcommerce = BigCommerceCredential.find_by_store_id(@store.id)
            begin
              params[:shop_name] = nil if params[:shop_name] == 'null'
              if @bigcommerce.nil?
                @store.big_commerce_credential = BigCommerceCredential.new(
                  shop_name: params[:shop_name])
                new_record = true
              else
                @bigcommerce.update_attributes(shop_name: params[:shop_name])
              end
              @store.save
            rescue ActiveRecord::RecordInvalid => e
              @result['status'] = false
              @result['messages'] = [@store.errors.full_messages,
                                     @store.big_commerce_credential.errors.full_messages]

            rescue ActiveRecord::StatementInvalid => e
              @result['status'] = false
              @result['messages'] = [e.message]
            end
            current_tenant = Apartment::Tenant.current
            cookies[:tenant_name] = {:value => current_tenant , :domain => :all, :expires => Time.now+20.minutes}
            cookies[:store_id] = {:value => @store.id , :domain => :all, :expires => Time.now+20.minutes}
          end

          if @store.store_type == 'Teapplix'
            @teapplix = TeapplixCredential.where(:store_id => @store.id)
            if @teapplix.blank?
              @teapplix = @store.build_teapplix_credential
              new_record = true
            else
              @teapplix = @teapplix.first
            end
            @teapplix.account_name = params[:account_name]
            @teapplix.username = params[:username]
            @teapplix.password = params[:password]
            @teapplix.gen_barcode_from_sku = params[:gen_barcode_from_sku]

            if @teapplix.import_shipped!=params[:import_shipped].to_b
              @teapplix.import_shipped = params[:import_shipped]
              @teapplix.import_open_orders = false
            elsif @teapplix.import_open_orders!=params[:import_open_orders].to_b
              @teapplix.import_open_orders = params[:import_open_orders]
              @teapplix.import_shipped = false
            end

            begin
              @store.save!
              @teapplix.save if !new_record
            rescue ActiveRecord::RecordInvalid => e
              @result['status'] = false
              @result['messages'] = [@store.errors.full_messages, @store.teapplix_credential.errors.full_messages]
            rescue ActiveRecord::StatementInvalid => e
              @result['status'] = false
              @result['messages'] = [e.message]
            end
          end
        else
          @result['status'] = false
          @result['messages'].push("Current user does not have permission to create or edit a store")
        end
        if !@store.nil? && @store.id
          @result["store_id"] = @store.id
        end
      end
    end

    respond_to do |format|
      format.json { render json: @result }
    end
  end

  def csv_map_data
    result = Hash.new
    result['product'] = CsvMap.find_all_by_kind('product')
    result['order'] = CsvMap.find_all_by_kind('order')
    result['kit'] = CsvMap.find_all_by_kind('kit')
    respond_to do |format|
      format.json { render json: result }
    end
  end

  def delete_csv_map
    result = Hash.new
    result['status'] = true
    result['messages'] = []
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

    respond_to do |format|
      format.json { render json: result }
    end
  end

  def update_csv_map
    result = Hash.new
    result['status'] = true
    result['messages'] = []
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

    respond_to do |format|
      format.json { render json: result }
    end
  end

  def csv_import_data
    @result = Hash.new
    @result["status"] = true
    @result["messages"] = []
    general_settings = GeneralSetting.all.first

    if !params[:id].nil?
      @store = Store.find(params[:id])
    else
      @result["status"] = false
      @result["messages"].push("No store selected")
    end

    if @result["status"]
      if !@store.nil?
        if params[:type].nil? || !['both', 'order', 'product', 'kit'].include?(params[:type])
          params[:type] = 'both'
        end
        if (params[:type] == 'order' && current_user.can?('import_orders'))||
          (params[:type] == 'both' && current_user.can?('import_orders') && current_user.can?('import_products')) ||
          (['product', 'kit'].include?(params[:type]) && current_user.can?('import_products'))
          @result['store_id'] = @store.id

          #check if previous mapping exists
          #else fill in defaults
          default_csv_map = {
            'name' => '',
            'map' => {
              'rows' => 2,
              'sep' => ',',
              'other_sep' => 0,
              'delimiter' => '"',
              'fix_width' => 0,
              'fixed_width' => 4,
              'contains_unique_order_items' => false,
              'generate_barcode_from_sku' => false,
              'use_sku_as_product_name' => false,
              'order_placed_at' => nil,
              'order_date_time_format' => 'Default',
              'day_month_sequence' => 'MM/DD',
              'map' => {}
            }
          }
          csv_map = CsvMapping.find_or_create_by_store_id(@store.id)
          # end check for mapping

          csv_directory = 'uploads/csv'
          current_tenant = Apartment::Tenant.current
          if ['both', 'order'].include?(params[:type])
            @result['order'] = Hash.new
            @result['order']['map_options'] = [
              {value: 'increment_id', name: 'Order number'},
              {value: 'order_placed_time', name: 'Order Date/Time'},
              {value: 'sku', name: 'SKU'},
              {value: 'product_name', name: 'Product Name'},
              {value: 'barcode', name: 'Barcode/UPC'},
              {value: 'qty', name: 'QTY'},
              {value: 'category', name: 'Product Category'},
              {value: 'product_weight', name: 'Weight Oz'},
              {value: 'product_instructions', name: 'Product Instructions'},
              {value: 'image', name: 'Image Absolute URL'},
              {value: 'firstname', name: '(First)Full Name'},
              {value: 'lastname', name: 'Last Name'},
              {value: 'email', name: 'Email'},
              {value: 'address_1', name: 'Address 1'},
              {value: 'address_2', name: 'Address 2'},
              {value: 'city', name: 'City'},
              {value: 'state', name: 'State'},
              {value: 'postcode', name: 'Postal Code'},
              {value: 'country', name: 'Country'},
              {value: 'method', name: 'Shipping Method'},
              {value: 'price', name: 'Order Total'},
              {value: 'customer_comments', name: 'Customer Comments'},
              {value: 'notes_internal', name: 'Internal Notes'},
              {value: 'notes_toPacker', name: 'Notes to Packer'},
              {value: 'tracking_num', name: 'Tracking Number'},
              {value: 'item_sale_price', name: 'Item Sale Price'},
              {value: 'secondary_sku', name: 'SKU 2'},
              {value: 'tertiary_sku', name: 'SKU 3'},
              {value: 'secondary_barcode', name: 'Barcode 2'},
              {value: 'tertiary_barcode', name: 'Barcode 3'},
              {value: 'custom_field_one', name: general_settings.custom_field_one},
              {value: 'custom_field_two', name: general_settings.custom_field_two}
            ]

            if csv_map.order_csv_map.nil?
              @result['order']['settings'] = default_csv_map
            else
              temp_mapping = csv_map.order_csv_map[:map]
              new_map = temp_mapping[:map].inject({}){|hash, (k, v)| hash.merge!(k => (v['value'].in?(%w(custom_field_one custom_field_two)) ? v.merge('name' => general_settings[v['value']]) : v)); hash}
              csv_map.order_csv_map.update_attributes(map: temp_mapping.merge(map: new_map))
              @result['order']['settings'] = csv_map.order_csv_map
            end

            order_file_path = File.join(csv_directory, "#{current_tenant}.#{@store.id}.order.csv")
            if File.exists? order_file_path
              # read 4 kb data
              # order_file_data = IO.read(open("#{ENV['S3_BASE_URL']}/#{current_tenant}/csv/order.#{@store.id}.csv"), 40960)
              order_file_data = Net::HTTP.get(URI.parse("#{ENV['S3_BASE_URL']}/#{current_tenant}/csv/order.#{@store.id}.csv")).split(/[\r\n]+/).first(200).join("\r\n")
              @result['order']['data'] = order_file_data
              File.delete(order_file_path)
            end
          end
          if ['both', 'product'].include?(params[:type])
            @result['product'] = Hash.new
            @result['product']['map_options'] = [
              {value: 'sku', name: 'SKU'},
              {value: 'barcode', name: 'Barcode'},
              {value: 'product_name', name: 'Name'},
              {value: 'inv_wh1', name: 'QTY On Hand'},
              {value: 'location_primary', name: 'Bin Location'},
              {value: 'product_images', name: 'Image Absolute URL'},
              {value: 'product_weight', name: 'Weight Oz'},
              {value: 'category_name', name: 'Category'},
              {value: 'product_instructions', name: 'Packing Instructions'},
              {value: 'receiving_instructions', name: 'Receiving Instructions'},
              {value: 'secondary_sku', name: 'SKU 2'},
              {value: 'tertiary_sku', name: 'SKU 3'},
              {value: 'secondary_barcode', name: 'Barcode 2'},
              {value: 'tertiary_barcode', name: 'Barcode 3'},
              {value: 'location_secondary', name: 'Bin Location 2'},
              {value: 'location_tertiary', name: 'Bin Location 3'}
            ]

            if csv_map.product_csv_map.nil?
              @result['product']['settings'] = default_csv_map
            else
              @result['product']['settings'] = csv_map.product_csv_map
            end

            product_file_path = File.join(csv_directory, "#{current_tenant}.#{@store.id}.product.csv")
            if File.exists? product_file_path
              product_file_data = IO.read(product_file_path, 40960)
              @result['product']['data'] = product_file_data
              File.delete(product_file_path)
            end
          end
          if ['both', 'kit'].include?(params[:type])
            @result['kit'] = Hash.new
            @result['kit']['map_options'] = [
              {value: 'kit_sku', name: 'KIT-SKU'},
              {value: 'kit_name', name: 'KIT-NAME'},
              {value: 'kit_barcode', name: 'KIT-BARCODE'},
              {value: 'part_sku', name: 'PART-SKU'},
              {value: 'part_name', name: 'PART-NAME'},
              {value: 'part_barcode', name: 'PART-BARCODE'},
              {value: 'part_qty', name: 'PART-QTY'},
              {value: 'scan_option', name:'SCAN-OPTION' }
            ]
            if csv_map.kit_csv_map.nil?
              @result['kit']['settings'] = default_csv_map
            else
              @result['kit']['settings'] = csv_map.kit_csv_map
            end

            kit_file_path = File.join(csv_directory, "#{current_tenant}.#{@store.id}.kit.csv")
            if File.exists? kit_file_path
              kit_file_data = IO.read(kit_file_path, 40960)
              @result['kit']['data'] = kit_file_data
              File.delete(kit_file_path)
            end
          end
        else
          @result['status'] = false
          @result['messages'].push('Not enough permissions')
        end
      else
        @result['status'] = false
        @result['messages'].push('Cannot find store')
      end
    end

    respond_to do |format|
      format.json { render json: @result }
    end
  end

  def csv_do_import
    @result = Hash.new
    @result['status'] = true
    @result['last_row'] = 0
    @result['messages'] = []

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

    if (params[:type] == 'order' && !current_user.can?('import_orders')) ||
      (['product', 'kit'].include?(params[:type]) && !current_user.can?('import_products'))
      @result['status'] = false
      @result['messages'].push("User does not have permissions to import #{params[:type]}")
    end

    if @result['status']
      #store mapping for later
      csv_map = CsvMapping.find_by_store_id(@store.id)
      if params[:type] =='product'
        if params[:name].blank?
          params[:name] = csv_map.store.name+' - Default Product Map'
        end
        if csv_map.product_csv_map_id.nil?
          map_data = CsvMap.create(:kind => 'product', :name => params[:name], :map => {})
          csv_map.product_csv_map_id = map_data.id
          csv_map.save
        else
          map_data = csv_map.product_csv_map
        end
      elsif params[:type] =='kit'
        if params[:name].blank?
          params[:name] = csv_map.store.name+' - Default Kit Map'
        end
        if csv_map.kit_csv_map_id.nil?
          map_data = CsvMap.create(:kind => 'kit', :name => params[:name], :map => {})
          csv_map.kit_csv_map_id = map_data.id
          csv_map.save
        else
          map_data = csv_map.kit_csv_map
        end
      elsif params[:type] == 'order'
        if params[:name].blank?
          params[:name] = csv_map.store.name+' - Default Order Map'
        end
        if csv_map.order_csv_map_id.nil?
          map_data = CsvMap.create(:kind => 'order', :name => params[:name], :map => {})
          csv_map.order_csv_map_id = map_data.id
          csv_map.save
        else
          map_data = csv_map.order_csv_map
        end
      end

      map_data.name = params[:name]

      map_data.map = {
        :rows => params[:rows],
        :sep => params[:sep],
        :other_sep => params[:other_sep],
        :delimiter => params[:delimiter],
        :fix_width => params[:fix_width],
        :fixed_width => params[:fixed_width],
        :import_action => params[:import_action],
        :contains_unique_order_items => params[:contains_unique_order_items],
        :generate_barcode_from_sku => params[:generate_barcode_from_sku],
        :use_sku_as_product_name => params[:use_sku_as_product_name],
        :order_date_time_format => params[:order_date_time_format],
        :day_month_sequence => params[:day_month_sequence],
        :map => params[:map]
      }
      map_data.save
      begin
        csv_map.save!
      rescue ActiveRecord::RecordInvalid => e
        @result['status'] = false
        @result['messages'].push(csv_map.errors.full_messages)
      rescue ActiveRecord::StatementInvalid => e
        @result['status'] = false
        @result['messages'].push(e.message)
      end
    end
    if @result['status']
      data = {}
      data[:flag] = params[:flag]
      data[:type] = params[:type]
      data[:fix_width] = params[:fix_width]
      data[:fixed_width] = params[:fixed_width]
      data[:sep] = params[:sep]
      data[:delimiter] = params[:delimiter]
      data[:rows] = params[:rows]
      data[:map] = params[:map]
      data[:store_id] = params[:store_id]
      data[:import_action] = params[:import_action]
      data[:contains_unique_order_items] = params[:contains_unique_order_items]
      data[:generate_barcode_from_sku] = params[:generate_barcode_from_sku]
      data[:use_sku_as_product_name] = params[:use_sku_as_product_name]
      data[:order_placed_at] = params[:order_placed_at]
      data[:order_date_time_format] = params[:order_date_time_format]
      data[:day_month_sequence] = params[:day_month_sequence]

      # Uncomment this when everything is moved to bulk actions
      # groove_bulk_actions = GrooveBulkActions.new
      # groove_bulk_actions.identifier = 'csv_import'
      # groove_bulk_actions.activity = params[:type]
      # groove_bulk_actions.save
      #
      # data[:bulk_action_id] = groove_bulk_actions.id
      #
      # import_csv = ImportCsv.new
      # import_csv.delay(:run_at =>1.seconds.from_now).import Apartment::Tenant.current, data


      # Comment everything after this line till next comment (i.e. the entire if block) when everything is moved to bulk actions
      if params[:type] == 'order'
        if OrderImportSummary.where(status: 'in_progress').empty?
          bulk_actions = Groovepacker::Orders::BulkActions.new
          bulk_actions.delay(:run_at => 1.seconds.from_now).import_csv_orders(Apartment::Tenant.current_tenant, @store.id, data.to_s, current_user.id)
          #bulk_actions.import_csv_orders(Apartment::Tenant.current_tenant, @store.id, data.to_s, current_user.id)
        else
          @result['status'] = false
          @result['messages'].push("Import is in progress. Try after it is complete")
        end

      elsif params[:type] == 'kit'
        groove_bulk_actions = GrooveBulkActions.new
        groove_bulk_actions.identifier = 'csv_import'
        groove_bulk_actions.activity = 'kit'
        groove_bulk_actions.save
        data[:bulk_action_id] = groove_bulk_actions.id
        import_csv = ImportCsv.new
        import_csv.delay(:run_at => 1.seconds.from_now).import Apartment::Tenant.current, data.to_s
        # import_csv.import(Apartment::Tenant.current, data.to_s)

      elsif params[:type] == 'product'
        product_import = CsvProductImport.find_by_store_id(@store.id)
        if product_import.nil?
          product_import = CsvProductImport.new
          product_import.store_id = @store.id
        end

        import_csv = ImportCsv.new
        delayed_job = import_csv.delay(:run_at => 1.seconds.from_now).import Apartment::Tenant.current, data.to_s
        # delayed_job = import_csv.import(Apartment::Tenant.current, data.to_s)

        product_import.delayed_job_id = delayed_job.id
        product_import.total = 0
        product_import.success = 0
        product_import.cancel = false
        product_import.status = 'scheduled'
        product_import.save
      end
      # Comment everything before this line till previous comment (i.e. the entire if block) when everything is moved to bulk actions

    end

    respond_to do |format|
      format.json { render json: @result }
    end
  end

  def csv_product_import_cancel
    result = Hash.new
    result['status'] = true
    result['success_messages'] = []
    result['notice_messages'] = []
    result['error_messages'] = []

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

      if product_import.save
        result['notice_messages'].push('Product Import marked for cancellation. Please wait for acknowledgement.')
      end

    end


    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: result }
    end
  end

  def change_store_status
    @result = Hash.new
    @result['status'] = true
    @result['messages'] =[]
    if current_user.can? 'add_edit_stores'
      params['_json'].each do |store|
        @store = Store.find(store["id"])
        @store.status = store["status"]
        if !@store.save
          @result['status'] = false
        end
      end
      OrderImportSummary.first.emit_data_to_user unless OrderImportSummary.first.nil?
    else
      @result["status"] = false
      @result["messages"].push('User does not have permissions to change store status')
    end


    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end

  def duplicate_store

    @result = Hash.new
    @result['status'] = true
    @result['messages'] = []

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


    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end

  def delete_store
    @result = Hash.new
    @result['status'] = false
    @result['messages'] = []
    if current_user.can? 'add_edit_stores'
      system_store_id = Store.find_by_store_type('system').id.to_s
      params['_json'].each do |store|
        @store = Store.where(id: store["id"]).first
        unless @store.nil?
          Product.update_all('store_id = '+system_store_id, 'store_id ='+@store.id.to_s)
          Order.update_all('store_id = '+system_store_id, 'store_id ='+@store.id.to_s)
          if @store.store_type == 'CSV'
            csv_mapping = CsvMapping.find_by_store_id(@store.id)
            unless csv_mapping.nil?
              csv_mapping.destroy
            end
            ftp_credential = FtpCredential.find_by_store_id(@store.id)
            ftp_credential.destroy unless ftp_credential.nil?
          end
          if @store.deleteauthentications && @store.destroy
            @result['status'] = true
          end
        end
      end
    else
      @result["status"] = false
      @result["messages"].push("User does not have permissions to delete store")
    end


    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end

  def show
    @store = Store.find_by_id(params[:id])
    @result = Hash.new

    if !@store.nil? then
      @result['status'] = true
      @result['store'] = @store
      access_restrictions = AccessRestriction.last
      @result['general_settings'] = GeneralSetting.first
      @result['current_tenant'] = Apartment::Tenant.current
      @result['host_url'] = get_host_url
      @result['access_restrictions'] = access_restrictions
      @result['credentials'] = @store.get_store_credentials
      if @store.store_type == 'CSV'
        @result['mapping'] = CsvMapping.find_by_store_id(@store.id)
      end
    else
      @result['status'] = false
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end

  def get_system
    @store = Store.find_by_store_type('system')
    @result = Hash.new

    if @store.nil?
      @result['status'] = false
    else
      @result['status'] = true
      @result['store'] = @store
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end

  def get_ebay_signin_url
    @result = Hash.new
    @result[:status] = true

    @store = Store.new
    @result = @store.get_ebay_signin_url
    session[:ebay_session_id] = @result['ebay_sessionid']
    @result['current_tenant'] = Apartment::Tenant.current

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end

  def ebay_user_fetch_token
    require "net/http"
    require "uri"
    @result = Hash.new
    devName = ENV['EBAY_DEV_ID']
    appName = ENV['EBAY_APP_ID']
    certName = ENV['EBAY_CERT_ID']
    @result['status'] = false
    if ENV['EBAY_SANDBOX_MODE'] == 'YES'
      url = "https://api.sandbox.ebay.com/ws/api.dll"
    else
      url = "https://api.ebay.com/ws/api.dll"
    end
    url = URI.parse(url)

    req = Net::HTTP::Post.new(url.path)
    req.add_field("X-EBAY-API-REQUEST-CONTENT-TYPE", 'text/xml')
    req.add_field("X-EBAY-API-COMPATIBILITY-LEVEL", "675")
    req.add_field("X-EBAY-API-DEV-NAME", devName)
    req.add_field("X-EBAY-API-APP-NAME", appName)
    req.add_field("X-EBAY-API-CERT-NAME", certName)
    req.add_field("X-EBAY-API-SITEID", 0)
    req.add_field("X-EBAY-API-CALL-NAME", "FetchToken")

    req.body ='<?xml version="1.0" encoding="utf-8"?>'+
      '<FetchTokenRequest xmlns="urn:ebay:apis:eBLBaseComponents">'+
      '<SessionID>'+session[:ebay_session_id]+'</SessionID>' +
      '</FetchTokenRequest>'
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
    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end

  def update_ebay_user_token
    require "net/http"
    require "uri"
    @result = Hash.new
    devName = ENV['EBAY_DEV_ID']
    appName = ENV['EBAY_APP_ID']
    certName = ENV['EBAY_CERT_ID']
    @result['status'] = false
    if ENV['EBAY_SANDBOX_MODE'] == 'YES'
      url = "https://api.sandbox.ebay.com/ws/api.dll"
    else
      url = "https://api.ebay.com/ws/api.dll"
    end
    url = URI.parse(url)
    @store = EbayCredentials.where(:store_id => params[:id])

    if !@store.nil? && @store.length > 0
      @store = @store.first
      req = Net::HTTP::Post.new(url.path)
      req.add_field("X-EBAY-API-REQUEST-CONTENT-TYPE", 'text/xml')
      req.add_field("X-EBAY-API-COMPATIBILITY-LEVEL", "675")
      req.add_field("X-EBAY-API-DEV-NAME", devName)
      req.add_field("X-EBAY-API-APP-NAME", appName)
      req.add_field("X-EBAY-API-CERT-NAME", certName)
      req.add_field("X-EBAY-API-SITEID", 0)
      req.add_field("X-EBAY-API-CALL-NAME", "FetchToken")

      req.body ='<?xml version="1.0" encoding="utf-8"?>'+
        '<FetchTokenRequest xmlns="urn:ebay:apis:eBLBaseComponents">'+
        '<SessionID>'+session[:ebay_session_id]+'</SessionID>' +
        '</FetchTokenRequest>'
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true
      res = http.start do |http_runner|
        http_runner.request(req)
      end
      ebaytoken_resp = MultiXml.parse(res.body)
      @result['response'] = ebaytoken_resp
      if ebaytoken_resp['FetchTokenResponse']['Ack'] == 'Success'
        @store.auth_token =
          ebaytoken_resp['FetchTokenResponse']['eBayAuthToken']
        @store.productauth_token =
          ebaytoken_resp['FetchTokenResponse']['eBayAuthToken']
        @store.ebay_auth_expiration =
          ebaytoken_resp['FetchTokenResponse']['HardExpirationTime']
        if @store.save
          @result['status'] = true
        end
      end
    else
      @result['status'] = false;
    end
    respond_to do |format|
      format.html { render layout: 'close_window' }
      format.json { render json: @result }
    end
  end

  def delete_ebay_token
    @result = Hash.new
    @result['status'] = false

    if params[:id] == 'undefined'
      session[:ebay_auth_token] = nil
      session[:ebay_auth_expiration] = nil
      @result['status'] = true
    else
      @store = Store.find(params[:id])
      if @store.store_type == 'Ebay'
        @ebaycredentials = EbayCredentials.where(:store_id => params[:id])
        @ebaycredentials = @ebaycredentials.first
        @ebaycredentials.auth_token = ''
        @ebaycredentials.productauth_token = ''
        @ebaycredentials.ebay_auth_expiration = ''
        session[:ebay_auth_token] = nil
        session[:ebay_auth_expiration] = nil
        if @ebaycredentials.save
          @result['status'] = true
        end
      end
    end
    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end

  def handle_ebay_redirect
    ebaytkn = params['ebaytkn']
    tknexp = params['tknexp']
    username = params['username']
    redirect = params['redirect']
    editstatus = params['editstatus']
    name = params['name']
    status = params['status']
    storetype = params['storetype']
    storeid = params['storeid']
    inventorywarehouseid = params['inventorywarehouseid']
    importimages = params['importimages']
    importproducts = params['importproducts']
    messagetocustomer = params['messagetocustomer']
    tenant_name = params['tenantname']

    # redirect_to (URI::encode("https://#{tenant_name}.groovepacker.com:3001//") + "#" + URI::encode("/settings/showstores/ebay?ebaytkn=#{ebaytkn}&tknexp=#{tknexp}&username=#{username}&redirect=#{redirect}&editstatus=#{editstatus}&name=#{name}&status=#{status}&storetype=#{storetype}&storeid=#{storeid}&inventorywarehouseid=#{inventorywarehouseid}&importimages=#{importimages}&importproducts=#{importproducts}&messagetocustomer=#{messagetocustomer}&tenantname=#{tenant_name}") )
    redirect_to (URI::encode("https://#{tenant_name}.#{ENV['HOST_NAME']}/") + URI::encode("stores/#{storeid}/update_ebay_user_token"))
  end

  def let_store_be_created
    render json: {
             can_create: Store.can_create_new?
           }
  end

  def verify_tags
    #store_id
    store = Store.find(params[:id])
    result = {
      status: true,
      messages: [],
      data: {
        verification_result: false,
        message: ""
      }
    }
    if store.store_type == 'Shipstation API 2'
      result[:data] = store.shipstation_rest_credential.verify_tags
    else
      result[:status] = false
      result[:messages] << "Cannot verify tags for this store"
    end
    render json: result
  end

  def update_all_locations
    #store_id
    store = Store.find(params[:id])
    result = {
      status: true,
      messages: [],
      data: {
        update_status: false,
        message: ""
      }
    }

    order_summary = OrderImportSummary.where(
      status: 'in_progress')

    if order_summary.empty? && store.store_type == 'Shipstation API 2'
      tenant = Apartment::Tenant.current
      Delayed::Job.where(queue: "importing_orders_"+tenant).destroy_all
      store.shipstation_rest_credential.update_all_locations(tenant, current_user)
    else
      result[:status] = false
      result[:error_messages] << "Import/Update is in progress"
    end

    render json: result
  end

  def export_active_products
    result = Hash.new
    tenant = Apartment::Tenant.current
    export_product = ExportSsProductsCsv.new
    export_product.delay.export_active_products(tenant)
    result["message"] = "Your export is being processed. It will be emailed to #{GeneralSetting.all.first.email_address_for_packer_notes} when it is ready." 
    # result['message'] = "expoting report started" 
    # GroovRealtime::emit('popup_display_for_on_demand_import', result, :tenant)
    render json: result
  end

  def pull_store_inventory
    @store = Store.find(params[:id])

    @result = Hash.new
    @result['status'] = true

    access_restriction = AccessRestriction.last

    tenant = Apartment::Tenant.current
    import_orders_obj = ImportOrders.new
    import_orders_obj.delay(:run_at => 1.seconds.from_now).init_import(tenant)

    if @store && current_user.can?('update_inventories')
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
      context.delay(:run_at => 1.seconds.from_now).pull_inventory
      #context.pull_inventory
      @result['message'] = "Your request for innventory pull has beed queued"
    else
      @result['status'] = false
      @result['message'] = "Either the the BigCommerce store is not setup properly or you don't have permissions to update inventories."
    end

    render json: @result
  end

  def push_store_inventory
    @store = Store.find(params[:id])

    @result = Hash.new
    @result['status'] = true

    tenant = Apartment::Tenant.current
    import_orders_obj = ImportOrders.new
    import_orders_obj.delay(:run_at => 1.seconds.from_now).init_import(tenant)

    if @store && current_user.can?('update_inventories')
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
      context.delay(:run_at => 1.seconds.from_now).push_inventory
      #context.push_inventory
    else
      @result['status'] = false
      @result['message'] = "Either the store is not present or you don't have permissions to update inventories."
    end

    render json: @result
  end

  def update_store_list
    @result = Hash.new
    @result['status'] = true
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

    render json: @result
  end

end
