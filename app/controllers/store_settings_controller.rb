class StoreSettingsController < ApplicationController
  before_filter :authenticate_user!, :except => [:handle_ebay_redirect]
  include StoreSettingsHelper
  def storeslist
    @stores = Store.where("store_type != 'system'")

    respond_to do |format|
      format.json { render json: @stores}
    end
  end


  def getactivestores
    @result = Hash.new
    @result['status'] = true
    @result['stores'] = Store.where("status = '1' AND store_type != 'system'")

    respond_to do |format|
      format.json { render json: @result}
    end
  end

  def store
    stores = Store.where("store_type != 'system'")
    store_count = stores.count
    max_stores = AccessRestriction.first.num_import_sources
    if store_count < max_stores
      true
    else
      false
    end
  end

  def createStore
    @result = Hash.new

    @result['status'] = true
    @result['store_id'] = 0
    @result['csv_import'] = false
    @result['messages'] =[]
    if current_user.can? 'add_edit_store'
      if !params[:id].nil?
        @store = Store.find(params[:id])
      else
        @store = Store.new
      end

      if params[:store_type].nil?
        @result['status'] = false
        @result['messages'].push('Please select a store type to create a store')
      else
        @store.name = params[:name] || get_default_warehouse_name
        @store.store_type = params[:store_type]
        @store.status = params[:status]
        @store.thank_you_message_to_customer = params[:thank_you_message_to_customer]
        @store.inventory_warehouse_id = params[:inventory_warehouse_id] || get_default_warehouse_id
      end

      if @result['status']

        if params[:import_images].nil?
          params[:import_images] = false
        end
        if params[:import_products].nil?
          params[:import_products] = false
        end
        if @store.store_type == 'Magento'
          @magento = MagentoCredentials.where(:store_id=>@store.id)

          if @magento.nil? || @magento.length == 0
            @magento = MagentoCredentials.new
            new_record = true
          else
            @magento = @magento.first
          end
          @magento.host = params[:host]
          @magento.username = params[:username]
          @magento.password = params[:password]
          @magento.api_key  = params[:api_key]

          @magento.import_products = params[:import_products]
          @magento.import_images = params[:import_images]

          @store.magento_credentials = @magento

          begin
            @store.save
            if !new_record
              @store.magento_credentials.save
            end
          rescue ActiveRecord::RecordInvalid => e
            @result['status'] = false
            @result['messages'] = [@store.errors.full_messages, @store.magento_credentials.errors.full_messages]

          rescue ActiveRecord::StatementInvalid => e
            @result['status'] = false
            @result['messages'] = [e.message]
          end
        end

        if @store.store_type == 'Amazon'
          @amazon = AmazonCredentials.where(:store_id=>@store.id)

          if @amazon.nil? || @amazon.length == 0
            @amazon = AmazonCredentials.new
            new_record = true
          else
            @amazon = @amazon.first
          end
          @amazon.marketplace_id = params[:marketplace_id]
          @amazon.merchant_id = params[:merchant_id]

          @amazon.import_products = params[:import_products]
          @amazon.import_images = params[:import_images]
          @amazon.show_shipping_weight_only = params[:show_shipping_weight_only]


          @store.amazon_credentials = @amazon

          begin
            @store.save
            if !new_record
              @store.amazon_credentials.save
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
          @ebay = EbayCredentials.where(:store_id=>@store.id)

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
              @store.ebay_credentials.save
            end
          rescue ActiveRecord::RecordInvalid => e
            @result['status'] = false
            @result['messages'] = [@store.errors.full_messages, @store.ebay_credentials.errors.full_messages]

          rescue ActiveRecord::StatementInvalid => e
            @result['status'] = false
            @result['messages'] = [e.message]
          end
          @result['store_id'] = @store.id
          @result['tenant_name'] = Apartment::Tenant.current_tenant
        end

        if @store.store_type == 'CSV'
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
            unless params[:orderfile].nil?
              path = File.join(csv_directory, "#{@store.id}.order.csv")
              File.open(path, "wb") { |f| f.write(params[:orderfile].read) }
              @result['csv_import'] = true
            end
            unless params[:productfile].nil?
              path = File.join(csv_directory, "#{@store.id}.product.csv")
              File.open(path, "wb") { |f| f.write(params[:productfile].read) }
              @result['csv_import'] = true
            end
          end
        end
        if @store.store_type == 'Shipstation'
          @shipstation = ShipstationCredential.where(:store_id=>@store.id)
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
              @store.shipstation_credential.save
            end
          rescue ActiveRecord::RecordInvalid => e
            @result['status'] = false
            @result['messages'] = [@store.errors.full_messages, @store.shipstation_credential.errors.full_messages]

          rescue ActiveRecord::StatementInvalid => e
            @result['status'] = false
            @result['messages'] = [e.message]
          end
        end
      else
        @result['status'] = false
        @result['messages'].push("Current user does not have permission to create or edit a store")

        if @store.id
          @result["store_id"] = @store.id
        end
      end
    else
      @result['status'] = false
      @result['messages'] = "You have reached the maximum limit of number of stores for your subscription."
    end

    respond_to do |format|
        format.json { render json: @result}
    end
  end

  def csvImportData
    @result = Hash.new
    @result["status"] = true
    @result["messages"] = []

    if !params[:id].nil?
      @store = Store.find(params[:id])
    else
      @result["status"] = false
      @result["messages"].push("No store selected")
    end

    if @result["status"]
      if !@store.nil?
        if params[:type].nil? || !["both","order","product"].include?(params[:type])
          params[:type] = "both"
        end
        if (params[:type] == "order" && current_user.can?('import_orders'))||
            (params[:type] == "both" && current_user.can?('import_orders') && current_user.can?('import_products')) ||
            (params[:type] == "product" && current_user.can?('import_products'))
          @result["store_id"] = @store.id

          #check if previous mapping exists
          #else fill in defaults
          default_csv_map = {:rows => 1, :sep => ',' , :other_sep => 0, :delimiter=>'"', :fix_width => 0, :fixed_width =>4, :map => {} }
          csv_map = CsvMapping.find_or_create_by_store_id(@store.id)
          csv_map_save = false
          if csv_map.order_map.blank?
            csv_map.order_map = default_csv_map
            csv_map_save = true
          end
          if csv_map.product_map.blank?
            csv_map.product_map = default_csv_map
            csv_map_save = true
          end
          if csv_map_save
            csv_map.save
          end
          # end check for mapping

          csv_directory = "uploads/csv"
          if ["both","order"].include?(params[:type])
            @result["order"] = Hash.new
            @result["order"]["map_options"] = [
                { value: "increment_id", name: "Order number"},
                { value: "order_placed_time", name: "Order placed"},
                { value: "sku", name: "SKU"},
                { value: "customer_comments", name: "Customer Comments"},
                { value: "qty", name: "Qty"},
                { value: "price", name: "Price"},
                { value: "firstname", name: "First name"},
                { value: "lastname", name: "Last name"},
                { value: "email", name: "Email"},
                { value: "address_1", name: "Address 1"},
                { value: "address_2", name: "Address 2"},
                { value: "city", name: "City"},
                { value: "state", name: "State"},
                { value: "postcode", name: "Postal Code"},
                { value: "country", name: "Country"},
                { value: "method", name: "Shipping Method"}
            ]
            @result["order"]["settings"] = csv_map.order_map
            order_file_path = File.join(csv_directory, "#{@store.id}.order.csv")
            if File.exists? order_file_path
              # read 4 mb data
              order_file_data = IO.read(order_file_path,4194304)
              @result["order"]["data"] = order_file_data
            end
          end
          if ["both","product"].include?(params[:type])
            @result["product"] = Hash.new
            @result["product"]["map_options"] = [
                { value:"sku" , name:"SKU"},
                { value: "product_name", name: "Product Name"},
                { value: "category_name", name: "Category Name"},
                { value: "inv_wh1", name: "Inventory"},
                { value: "product_images", name: "Product Images"},
                { value: "product_type", name: "Product Type"},
                { value: "location_primary", name: "Location/Bin"},
                { value: "barcode", name: "Barcode Value"}
            ]
            @result["product"]["settings"] = csv_map.product_map
            product_file_path = File.join(csv_directory, "#{@store.id}.product.csv")
            if File.exists? product_file_path
              product_file_data = IO.read(product_file_path,4194304)
              @result["product"]["data"] = product_file_data
            end
          end
        else
          @result["status"] = false
          @result["messages"].push("Not enough permissions")
        end
      else
        @result["status"] = false
        @result["messages"].push("Cannot find store")
      end
    end

    respond_to do |format|
      format.json { render json: @result}
    end
  end

  def csvDoImport
    @result = Hash.new
    @result["status"] = true
    @result["last_row"] = 0
    @result["messages"] = []

    if params[:store_id]
      @store = Store.find_by_id params[:store_id]
      if @store.nil?
        @result["status"] = false
        @result["messages"].push("Store doesn't exist")
      end
    else
      @result["status"] = false
      @result["messages"].push("No store selected")
    end

    if params[:type].nil? || !["order","product"].include?(params[:type])
      @result["status"] = false
      @result["messages"].push("No Type specified to import")
    end

    if (params[:type] == "order" && !current_user.can?('import_orders')) ||
        (params[:type] == "product" && !current_user.can?('import_products'))
      @result["status"] = false
      @result["messages"].push("User does not have permissions to import #{params[:type]}")
    end

    if @result["status"]
      #store mapping for later
      csv_map = CsvMapping.find_by_store_id(@store.id)
      csv_map["#{params[:type]}_map"] = {
          :rows => params[:rows],
          :sep => params[:sep] ,
          :other_sep => params[:other_sep],
          :delimiter=> params[:delimiter],
          :fix_width => params[:fix_width],
          :fixed_width => params[:fixed_width],
          :map => params[:map]
      }
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
    logger.info "CSV Map stored."
    if @result["status"]
      csv_directory = "uploads/csv"
      file_path = File.join(csv_directory, "#{params[:store_id]}.#{params[:type]}.csv")
      if File.exists? file_path
        final_record = []
        if params[:fix_width] == 1
          initial_split = IO.readlines(file_path)
          initial_split.each do |single|
            final_record.push(single.scan(/.{1,#{params[:fixed_width]}}/m))
          end
        else
          require 'csv'
          CSV.foreach(file_path,:col_sep => params[:sep], :quote_char => params[:delimiter] ) do |single|
            final_record.push(single)
          end
        end
        if params[:rows].to_i && params[:rows].to_i > 1
          final_record.shift(params[:rows].to_i - 1)
        end
        mapping = {}
        params[:map].each do |map_single|
          if map_single[1][:value] != 'none'
            mapping[map_single[1][:value]] = map_single[0].to_i
          end
        end

        order_map = [
          "address_1",
          "address_2",
          "city",
          "country",
          "customer_comments",
          "email",
          "firstname",
          "increment_id",
          "lastname",
          "method",
          "postcode",
          "sku",
          "state",
          "price",
          "qty"
        ]
        final_record.delete_at(0) if final_record.length > 0
        final_record.each_with_index do |single_row,index|
          if params[:type] == "order"
            order = Order.new
            order.store = @store
            #order_placed_time,price,qty
            logger.info mapping.to_s
            order_required = ["qty","sku","increment_id"]
            order_map.each do |single_map|
              if !mapping[single_map].nil? && mapping[single_map] >= 0
                #if sku, create order item with product id, qty
                if single_map == 'sku'
                  product_skus = ProductSku.where(:sku => single_row[mapping[single_map]])
                  if product_skus.length > 0
                    order_item  = OrderItem.new
                    order_item.product = product_skus.first.product
                    order_item.sku = single_row[mapping['sku']]
                    if !mapping['qty'].nil? && mapping['qty'] >= 0
                      order_item.qty = single_row[mapping['qty']]
                      order_required.delete('qty')
                    end
                    order.order_items << order_item
                  else # no sku is found
                    product = Product.new
                    product.name = 'Product created from order import'

                    sku = ProductSku.new
                    sku.sku = single_row[mapping['sku']]
                    product.product_skus << sku
                    product.store_product_id = 0
                    product.store = @store
                    product.save

                    order_item  = OrderItem.new
                    order_item.product = product
                    order_item.sku = single_row[mapping['sku']]
                    if !mapping['qty'].nil? && mapping['qty'] >= 0
                      order_item.qty = single_row[mapping['qty']]
                      order_required.delete('qty')
                    end
                    order.order_items << order_item
                  end
                end
                  #if product id cannot be found with SKU, then create product with product name and SKU


                order[single_map] = single_row[mapping[single_map]]

                if order_required.include? single_map
                  order_required.delete(single_map)
                end
              end
            end
            logger.info order_required.to_s
            if order_required.length > 0
              @result["status"] = false
              order_required.each do |required_element|
                @result["messages"].push("#{required_element} is missing.")
              end
            end
            if @result["status"]
              if !mapping["order_placed_time"].nil? && mapping["order_placed_time"] > 0
                begin
                  require 'time'
                  time = Time.parse(single_row[mapping["order_placed_time"]])
                  order["order_placed_time"] = time
                rescue ArgumentError => e
                  #@result["status"] = true
                  @result["messages"].push("Order Placed has bad parameter - #{single_row[mapping['order_placed_time']]}")
                end
              end
              if @result["status"]
                begin
                if Order.where(:increment_id=> order.increment_id).length == 0
                  order.status = 'onhold'
                  order.save!
                  order.update_order_status
                end
                rescue ActiveRecord::RecordInvalid => e
                  @result['status'] = false
                  @result['messages'].push(order.errors.full_messages)
                rescue ActiveRecord::StatementInvalid => e
                  @result['status'] = false
                  @result['messages'].push(e.message)
                end
              end
            end
          else
            #product import code here
            product = Product.new
            product.store = @store
            product.store_product_id = 0
            product.name = ""
            if !mapping['product_name'].nil? && mapping['product_name'] > 0 &&
              Product.where(:name=>single_row[mapping['product_name']]).length == 0
              product.name = single_row[mapping['product_name']]
            end
            if !mapping['product_type'].nil? && mapping['product_type'] > 0
              product.product_type = single_row[mapping['product_type']]
            end

            #add inventory warehouses
            if !!mapping['location_primary'].nil? && !mapping['inv_wh1'].nil?
              product_inventory = ProductInventoryWarehouses.new
              valid_inventory = false
              if !mapping['inv_wh1'].nil? && mapping['inv_wh1'] > 0
                product_inventory.qty = single_row[mapping['inv_wh1']]
                valid_inventory &= true
              end
              if !mapping['location_primary'].nil? && mapping['location_primary'] != ''
                product_inventory.location_primary = single_row[mapping['location_primary']]
                valid_inventory &= true
              end
              product.product_inventory_warehousess << product_inventory if valid_inventory
            end

            #add product categories
            if !mapping['category_name'].nil? && mapping['category_name'] > 0
              unless single_row[mapping['category_name']].nil?
                cats = single_row[mapping['category_name']].split(",")
                cats.each do |single_cat|
                  product_cat = ProductCat.new
                  product_cat.category = single_cat
                  product.product_cats << product_cat
                end
              end
            end

            if !mapping['product_images'].nil? && mapping['product_images'] > 0
              unless single_row[mapping['product_images']].nil?
                images = single_row[mapping['product_images']].split(",")
                images.each do |single_image|
                  product_image = ProductImage.new
                  product_image.image = single_image
                  product.product_images << product_image
                end
              end
            end

            if !mapping['sku'].nil? && mapping['sku'] > 0
              unless single_row[mapping['sku']].nil?
                skus = single_row[mapping['sku']].split(",")
                skus.each do |single_sku|
                  if ProductSku.where(:sku=>single_sku).length == 0
                    product_sku = ProductSku.new
                    product_sku.sku = single_sku
                    product_sku.purpose = "primary"
                    product.product_skus << product_sku
                  end
                end
              end
            end
            if !mapping['barcode'].nil? && mapping['barcode'] > 0
              unless single_row[mapping['barcode']].nil?
                barcodes = single_row[mapping['barcode']].split(",")
                barcodes.each do |single_barcode|
                  if ProductBarcode.where(:barcode => single_barcode).length == 0
                    product_barcode = ProductBarcode.new
                    product_barcode.barcode = single_barcode
                    product.product_barcodes << product_barcode
                  end
                end
              end
            end
            if @result["status"]
              begin
                if product.name != 'name' && product.name != ''
                  product.save!
                  product.update_product_status
                end
              rescue ActiveRecord::RecordInvalid => e
                @result['status'] = false
                @result['messages'].push(product.errors.full_messages)
              rescue ActiveRecord::StatementInvalid => e
                @result['status'] = false
                @result['messages'].push(e.message)
              end
            end
          end
          unless @result["status"]
            @result["last_row"] = index
            if index != 0
              @result["messages"].push("Import halted because of errors, we have adjusted rows to the ones already imported.")
            end
            break
          end
        end
      else
        @result["messages"].push("No file present to import #{params[:type]}")
      end
    end

    respond_to do |format|
      format.json { render json: @result}
    end
  end

  def changestorestatus
    @result = Hash.new
    @result['status'] = true
    @result['messages'] =[]
    if current_user.can? 'add_edit_stores'
      params['_json'].each do|store|
        @store = Store.find(store["id"])
        @store.status = store["status"]
        if !@store.save
          @result['status'] = false
        end
      end
    else
      @result["status"] = false
      @result["messages"].push("User does not have permissions to change store status")
    end


    respond_to do |format|
        format.html # show.html.erb
        format.json { render json: @result }
    end
  end

  def duplicatestore

    @result = Hash.new
    @result['status'] = true
    @result['messages'] = []

    if current_user.can? 'add_edit_stores'
      params['_json'].each do|store|
        @store = Store.find(store["id"])

        @newstore = @store.dup
        index = 0
        @newstore.name = @store.name+"(duplicate"+index.to_s+")"
        @storeslist = Store.where(:name=>@newstore.name)
        begin
          index = index + 1
          @newstore.name = @store.name+"(duplicate"+index.to_s+")"
          @storeslist = Store.where(:name=>@newstore.name)
        end while(!@storeslist.nil? && @storeslist.length > 0)

        if !@newstore.save(:validate => false) || !@newstore.dupauthentications(@store.id)
          @result['status'] = false
          @result['messages'] = @newstore.errors.full_messages
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

  def deletestore
    @result = Hash.new
    @result['status'] = false
    @result['messages'] = []
    if current_user.can? 'add_edit_stores'
      params['_json'].each do|store|
        @store = Store.find(store["id"])
        if @store.deleteauthentications && @store.destroy
          @result['status'] = true
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

  def getstoreinfo
    @store = Store.find(params[:id])
    @result = Hash.new

    if !@store.nil? then
      @result['status'] = true
      @result['store'] = @store
      @result['credentials'] = @store.get_store_credentials
    else
      @result['status'] = false
    end

    respond_to do |format|
        format.html # show.html.erb
        format.json { render json: @result }
    end
  end

  def getebaysigninurl
    @result = Hash.new
    @result[:status] = true
    if store
      @store = Store.new
      @result = @store.get_ebay_signin_url
      session[:ebay_session_id] = @result['ebay_sessionid']
      @result['current_tenant'] = Apartment::Tenant.current_tenant
    else
      @result[:status] = false
    end
    respond_to do |format|
        format.html # show.html.erb
        format.json { render json: @result }
    end
  end

  def ebayuserfetchtoken
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
    puts "fetch token response:" + ebaytoken_resp.inspect
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
  def updateebayusertoken
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
    @store = EbayCredentials.where(:store_id=>params[:storeid])

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
        format.html # show.html.erb
        format.json { render json: @result }
    end
  end
  def deleteebaytoken
    @result = Hash.new
    @result['status'] = false

    if params[:storeid] == 'undefined'
        session[:ebay_auth_token] = nil
        session[:ebay_auth_expiration] = nil
        @result['status'] = true
    else
      @store = Store.find(params[:storeid])
      if @store.store_type == 'Ebay'
        @ebaycredentials = EbayCredentials.where(:store_id=>params[:storeid])
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
    redirect_to (URI::encode("https://#{tenant_name}.groovepacker.com//") + "#" + URI::encode("/settings/showstores/ebay?ebaytkn=#{ebaytkn}&tknexp=#{tknexp}&username=#{username}&redirect=#{redirect}&editstatus=#{editstatus}&name=#{name}&status=#{status}&storetype=#{storetype}&storeid=#{storeid}&inventorywarehouseid=#{inventorywarehouseid}&importimages=#{importimages}&importproducts=#{importproducts}&messagetocustomer=#{messagetocustomer}&tenantname=#{tenant_name}") )
  end
end


