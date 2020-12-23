module Groovepacker
  module Stores
    class LibStores

    	def initialize(store, params, result)
    		@store = store
    		@result = result
    		@params = params
    	end

  		def amazon_update_create
  			params = @params
		    @amazon = AmazonCredentials.where(:store_id => @store.id)
		    if @amazon.nil? || @amazon.length == 0
		      @amazon = AmazonCredentials.new
		      new_record = true
		    else
		      @amazon = @amazon.first
		    end
		    @amazon.assign_attributes(:store_id => @store.id ,:marketplace_id => params[:marketplace_id], :merchant_id => params[:merchant_id], :mws_auth_token => params[:mws_auth_token], :import_products => params[:import_products], :import_images => params[:import_images], :show_shipping_weight_only => params[:show_shipping_weight_only], :unshipped_status => params[:unshipped_status], :shipped_status => params[:shipped_status].to_boolean, :afn_fulfillment_channel => params[:afn_fulfillment_channel].to_boolean, :mfn_fulfillment_channel => params[:mfn_fulfillment_channel].to_boolean)
		    @amazon.save if !new_record
		    @store.amazon_credentials = @amazon
		    begin
		      @store.save!
		      @amazon.save if !new_record
		    rescue ActiveRecord::RecordInvalid => e
		      @result['status'] = false
		      @result['messages'] = [@store.errors.full_messages, @store.amazon_credentials.errors.full_messages]
		    rescue ActiveRecord::StatementInvalid => e
		      @result['status'] = false
		      @result['messages'] = [e.message]
		    end
		    @result
			end

			def ebay_update_create(session)
				params = @params
		    @ebay = EbayCredentials.where(:store_id => @store.id)
		    @ebay = @ebay.nil? || @ebay.length == 0 ? EbayCredentials.new : @ebay.first
		    @ebay.auth_token = session[:ebay_auth_token] if !session[:ebay_auth_token].nil?
		    @ebay.productauth_token = session[:ebay_auth_token] if !session[:ebay_auth_token].nil?
		    @ebay.ebay_auth_expiration = session[:ebay_auth_expiration]
		    @ebay.import_products = params[:import_products]
		    @ebay.import_images = params[:import_images]
		    @ebay.shipped_status = params[:shipped_status].to_boolean
		    @ebay.unshipped_status = params[:unshipped_status].to_boolean
		    @store.ebay_credentials = @ebay
		    new_record = true if @ebay.id.blank?
		    begin
		      @store.save!
		      @ebay.save if !new_record
		    rescue ActiveRecord::RecordInvalid => e
		      @result['status'] = false
		      @result['messages'] = [@store.errors.full_messages, @store.ebay_credentials.errors.full_messages]
		    rescue ActiveRecord::StatementInvalid => e
		      @result['status'] = false
		      @result['messages'] = [e.message]
		    end
		    @result['store_id'] = @store.id
		    @result['tenant_name'] = Apartment::Tenant.current
		    @result
			end

			def csv_update_create
				params = @params
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
		        text_file_data = params[:orderfile].read
		        order_file_data = text_file_data.force_encoding('UTF-8').gsub(/\r?\n/, "\r\n") rescue text_file_data.force_encoding("ISO-8859-1").encode('UTF-8').gsub(/\r?\n/, "\r\n")
		        begin
			      	if @store.fba_import
			      		amazon_fba = Groovepacker::Stores::AmazonFbaStore.new(@store, params, @result)
			      		order_file_data = amazon_fba.fba_csv_data(order_file_data)
			      	end
			      rescue
			      end
			      $redis.set("#{current_tenant}/original_file_name", params["orderfile"].original_filename)
		        File.open(path, "wb") { |f| f.write(order_file_data) }
		        $redis.set("#{ENV['S3_BASE_URL']}/#{current_tenant}/csv/order.#{@store.id}.csv", order_file_data.split("\n").first(200).join("\n"))
		        GroovS3.create_public_csv(current_tenant, 'order', @store.id, order_file_data)
		        @result['csv_import'] = true
		      end
		      unless params[:productfile].nil?
		        path = File.join(csv_directory, "#{current_tenant}.#{@store.id}.product.csv")
		        product_file_data = params[:productfile].read
		        File.open(path, "wb") { |f| f.write(product_file_data) }
		        $redis.set("#{ENV['S3_BASE_URL']}/#{current_tenant}/csv/product.#{@store.id}.csv", product_file_data)
		        GroovS3.create_public_csv(current_tenant, 'product', @store.id, product_file_data)
		        @result['csv_import'] = true
		      end
		      unless params[:kitfile].nil?
		        path = File.join(csv_directory, "#{current_tenant}.#{@store.id}.kit.csv")
		        kit_file_data = params[:kitfile].read
		        File.open(path, "wb") { |f| f.write(kit_file_data) }
		        $redis.set("#{ENV['S3_BASE_URL']}/#{current_tenant}/csv/kit.#{@store.id}.csv", kit_file_data)
		        GroovS3.create_public_csv(current_tenant, 'kit', @store.id, kit_file_data)
		        @result['csv_import'] = true
		      end
		    end
		    @result
			end

			def shipstation_rest_update_create
				params = @params
		    @shipstation = ShipstationRestCredential.where(:store_id => @store.id)
		    if @shipstation.nil? || @shipstation.length == 0
		      @shipstation = ShipstationRestCredential.new
		      new_record = true
		    else
		      @shipstation = @shipstation.first
		    end
		    @shipstation.api_key = params[:api_key]
		    @shipstation.api_secret = params[:api_secret]
		    @shipstation.shall_import_awaiting_shipment = params[:shall_import_awaiting_shipment].to_boolean
		    @shipstation.shall_import_shipped = params[:shall_import_shipped].to_boolean
		    @shipstation.shall_import_pending_fulfillment = params[:shall_import_pending_fulfillment].to_boolean
		    @shipstation.warehouse_location_update = params[:warehouse_location_update].to_boolean
		    @shipstation.shall_import_customer_notes = params[:shall_import_customer_notes].to_boolean
		    @shipstation.shall_import_internal_notes = params[:shall_import_internal_notes].to_boolean
		    @shipstation.regular_import_range = params[:regular_import_range] unless params[:regular_import_range].nil?
		    @shipstation.gen_barcode_from_sku = params[:gen_barcode_from_sku].to_boolean
		    @shipstation.return_to_order = params[:return_to_order].to_boolean
		    @shipstation.import_upc = params[:import_upc].to_boolean
		    @shipstation.allow_duplicate_order = params[:allow_duplicate_order].to_boolean
		    @shipstation.tag_import_option = params[:tag_import_option].to_boolean
				@shipstation.import_tracking_info = params[:import_tracking_info].to_boolean
				@shipstation.postcode = params[:postcode] || ''
		    @shipstation.order_import_range_days = params[:order_import_range_days].to_i if params[:order_import_range_days].present? && params[:order_import_range_days] != 'undefined'
		    @store.shipstation_rest_credential = @shipstation
		    begin
		      @store.save!
		      @shipstation.save if !new_record
		    rescue ActiveRecord::RecordInvalid => e
		      @result['status'] = false
		      @result['messages'] = [@store.errors.full_messages, @store.shipstation_rest_credential.errors.full_messages]
		    rescue ActiveRecord::StatementInvalid => e
		      @result['status'] = false
		      @result['messages'] = [e.message]
		    end
		    @result
			end

			def shipping_easy_update_create
	            params = @params
			    @shippingeasy = @store.shipping_easy_credential || @store.create_shipping_easy_credential
			    new_record = true unless @shippingeasy.persisted?
			    @shippingeasy.attributes = {  api_key: params[:api_key], api_secret: params[:api_secret], store_api_key: params[:store_api_key], import_ready_for_shipment: params[:import_ready_for_shipment].to_boolean, import_shipped: params[:import_shipped].to_boolean, gen_barcode_from_sku: params[:gen_barcode_from_sku].to_boolean, ready_to_ship: params[:ready_to_ship].to_boolean, import_upc: params[:import_upc].to_boolean, allow_duplicate_id: params[:allow_duplicate_id].to_boolean}
			    @shippingeasy.save
			    @shippingeasy.import_ready_for_shipment = false  if @shippingeasy.ready_to_ship || @shippingeasy.import_shipped
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
			    @result
			end

			def shipwork_update_create
				params = @params
		    @shipworks = ShipworksCredential.find_by_store_id(@store.id)
		    begin
		      if @shipworks.nil?
		        @store.shipworks_credential = ShipworksCredential.new( auth_token: Store.get_sucure_random_token, import_store_order_number: params[:import_store_order_number].to_boolean, shall_import_in_process: params[:shall_import_in_process].to_boolean, shall_import_new_order: params[:shall_import_new_order].to_boolean, shall_import_not_shipped: params[:shall_import_not_shipped].to_boolean, shall_import_shipped: params[:shall_import_shipped].to_boolean, shall_import_no_status: params[:shall_import_no_status].to_boolean, shall_import_ignore_local: params[:shall_import_ignore_local].to_boolean, gen_barcode_from_sku: params[:gen_barcode_from_sku].to_boolean)
		        new_record = true
		      else
		        @shipworks.update_attributes( import_store_order_number: params[:import_store_order_number].to_boolean, shall_import_in_process: params[:shall_import_in_process].to_boolean, shall_import_new_order: params[:shall_import_new_order].to_boolean, shall_import_not_shipped: params[:shall_import_not_shipped].to_boolean, shall_import_shipped: params[:shall_import_shipped].to_boolean, shall_import_no_status: params[:shall_import_no_status].to_boolean, shall_import_ignore_local: params[:shall_import_ignore_local].to_boolean, gen_barcode_from_sku: params[:gen_barcode_from_sku].to_boolean)
		      end
		      @store.save
		    rescue ActiveRecord::RecordInvalid => e
		      @result['status'] = false
		      @result['messages'] = [@store.errors.full_messages, @store.shipstation_credential.errors.full_messages]
		    rescue ActiveRecord::StatementInvalid => e
		      @result['status'] = false
		      @result['messages'] = [e.message]
		    end
				@result
			end

			def shopify_update_create
				params = @params
		    @shopify = ShopifyCredential.find_by_store_id(@store.id)
		    begin
					params[:shop_name] = nil if params[:shop_name] == 'null'
		      params[:shop_name] = params[:shop_name].gsub(/[,()'".]+\z/,'') if params[:shop_name] != 'null' && params[:shop_name].present?
		      if @shopify.nil?
		        @store.shopify_credential = ShopifyCredential.new(shop_name: params[:shop_name])
		        new_record = true
		      else
		        @shopify.update_attributes(shop_name: params[:shop_name], shopify_status: params[:shopify_status], shipped_status: params[:shipped_status].to_b, unshipped_status: params[:unshipped_status].to_b, partial_status:  params[:partial_status].to_b, modified_barcode_handling: params[:modified_barcode_handling], generating_barcodes: params[:generating_barcodes], import_inventory_qoh: params[:import_inventory_qoh], import_updated_sku: params[:import_updated_sku], updated_sku_handling: params[:updated_sku_handling], permit_shared_barcodes: params[:permit_shared_barcodes])
		      end
		      @store.save
		    rescue ActiveRecord::RecordInvalid => e
		      @result['status'] = false
		      @result['messages'] = [@store.errors.full_messages, @store.shopify_credential.errors.full_messages]
		    rescue ActiveRecord::StatementInvalid => e
		      @result['status'] = false
		      @result['messages'] = [e.message]
		    end
				@result
			end

			def bigcommerce_update_create
				params = @params
		    @bigcommerce = BigCommerceCredential.find_by_store_id(@store.id)
		    begin
		      params[:shop_name] = nil if params[:shop_name] == 'null'
		      if @bigcommerce.nil?
		        @store.big_commerce_credential = BigCommerceCredential.new(shop_name: params[:shop_name])
		        new_record = true
		      else
		        @bigcommerce.update_attributes(shop_name: params[:shop_name])
		      end
		      @store.save
		    rescue ActiveRecord::RecordInvalid => e
		      @result['status'] = false
		      @result['messages'] = [@store.errors.full_messages, @store.big_commerce_credential.errors.full_messages]
		    rescue ActiveRecord::StatementInvalid => e
		      @result['status'] = false
		      @result['messages'] = [e.message]
		    end
				@result
			end

			def teapplix_update_create
				params = @params
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
		    @result
			end

			def magento_update_create
				params = @params
		    @magento = MagentoCredentials.where(:store_id => @store.id)
		    if @magento.blank?
		      @magento = @store.build_magento_credentials
		      new_record = true
		    else
		      @magento = @magento.first
		    end
		    host_url = params[:host].sub(/(\/)+$/,'') rescue nil
		    @magento.assign_attributes(:host => host_url, :username => params[:username], :api_key => params[:api_key], :shall_import_processing => params[:shall_import_processing],:shall_import_pending => params[:shall_import_pending], :shall_import_closed => params[:shall_import_closed], :shall_import_complete => params[:shall_import_complete], :shall_import_fraud => params[:shall_import_fraud], :enable_status_update => params[:enable_status_update], :status_to_update => params[:status_to_update], :push_tracking_number => params[:push_tracking_number], :import_products => params[:import_products], :import_images => params[:import_images], :updated_patch => params[:updated_patch])
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
		    @result
			end

			def magento_rest_update_create
				params = @params
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
		    @magento_rest.assign_attributes(:store_version => params[:store_version], :api_key => params[:api_key], :api_secret => params[:api_secret], :import_categories => params[:import_categories], :import_images => params[:import_images], :gen_barcode_from_sku => params[:gen_barcode_from_sku])
		    @magento_rest.store_token = Store.get_sucure_random_token(20).gsub("=","").gsub("/","") if @magento_rest.store_token.blank?
		    begin
		      @store.save!
		      @magento_rest.save if !new_record
		    rescue ActiveRecord::RecordInvalid => e
		      @result['status'] = false
		      @result['messages'] = [@store.errors.full_messages, @store.magento_rest_credential.errors.full_messages]
		    rescue ActiveRecord::StatementInvalid => e
		      @result['status'] = false
		      @result['messages'] = [e.message]
		    end
		    @result
			end
    end
  end
end