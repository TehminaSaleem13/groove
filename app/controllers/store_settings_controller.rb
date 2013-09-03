class StoreSettingsController < ApplicationController
  def storeslist
    @stores = Store.all

    respond_to do |format|
      format.json { render json: @stores}
    end
  end

  def createStore
    @result = Hash.new
    
    if !params[:id].nil?
      @store = Store.find(params[:id])
    else
      @store = Store.new
    end
    
    @store.name= params[:name]
    @store.store_type = params[:store_type]
    @store.status = params[:status]
    @result['status'] = true
    @result['store_id'] = 0
    @result['csv_import'] = false

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

        @magento.producthost = params[:producthost]
        @magento.productusername = params[:productusername]
        @magento.productpassword = params[:productpassword]
        @magento.productapi_key  = params[:productapi_key]

        @magento.import_products = params[:import_products]
        @magento.import_images = params[:import_images]

        @store.magento_credentials = @magento

          begin
              @store.save!
              if !new_record
                @store.magento_credentials.save!
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
        @amazon.access_key_id = params[:access_key_id]
        @amazon.app_name = params[:app_name]
        @amazon.app_version = params[:app_version]
        @amazon.marketplace_id = params[:marketplace_id]
        @amazon.merchant_id = params[:merchant_id]
        @amazon.secret_access_key = params[:secret_access_key]

        @amazon.productaccess_key_id = params[:productaccess_key_id]
        @amazon.productapp_name = params[:productapp_name]
        @amazon.productapp_version = params[:productapp_version]
        @amazon.productmarketplace_id = params[:productmarketplace_id]
        @amazon.productmerchant_id = params[:productmerchant_id]
        @amazon.productsecret_access_key = params[:productsecret_access_key]

        @amazon.import_products = params[:import_products]
        @amazon.import_images = params[:import_images]

        @store.amazon_credentials = @amazon

        begin
            @store.save!
            if !new_record
              @store.amazon_credentials.save!
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

        @ebay.app_id = params[:ebay_app_id]
        @ebay.auth_token = params[:ebay_auth_token]
        @ebay.cert_id = params[:ebay_cert_id]
        @ebay.dev_id = params[:ebay_dev_id]

        @ebay.productapp_id = params[:productebay_app_id]
        @ebay.productauth_token = params[:productebay_auth_token]
        @ebay.productcert_id = params[:productebay_cert_id]
        @ebay.productdev_id = params[:productebay_dev_id]
        
        @ebay.import_products = params[:import_products]
        @ebay.import_images = params[:import_images]

        @store.ebay_credentials = @ebay

        begin
            @store.save!
            if !new_record
              @store.ebay_credentials.save!
            end
            rescue ActiveRecord::RecordInvalid => e
              @result['status'] = false
              @result['messages'] = [@store.errors.full_messages, @store.ebay_credentials.errors.full_messages] 

            rescue ActiveRecord::StatementInvalid => e
              @result['status'] = false
              @result['messages'] = [e.message]
        end
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
    end
    
    respond_to do |format|
        format.json { render json: @result}
    end
  end

  def csvImportData
    @result = Hash.new
    @result["status"] = true
    if !params[:id].nil?
      @store = Store.find(params[:id])
    else
      @result["status"] = false
    end

    if @result["status"]
      if !@store.nil?
        if params[:type].nil? || !["both","order","product"].include?(params[:type])
          params[:type] = "both"
        end
        @result["store_id"] = @store.id
        @result["order"] = Hash.new
        @result["product"] = Hash.new
        #check if previous mapping exists
        #else fill in defaults
        csvmap = CsvMapping.find_or_create_by_store_id(@store.id)
=begin
         @result["product"]["map_options"] = [
            [ value:"sku" , name:"SKU"],
            [ value: "product_name", name: "Product Name"],
            [ value: "category_name", name: "Category Name"],
            [ value: "inv_wh1", name: "Inventory"],
            [ value: "product_images", name: "Product Images"],
            [ value: "location_primary", name: "Location/Bin"],
            [ value: "barcode", name: "Barcode Value"]
        ]

        @result["order"]["map_options"] = [
            [ value: "increment_id", name: "Order number"],
            [ value: "order_placed_time", name: "Order placed"],
            [ value: "sku", name: "SKU"],
            [ value: "customer_comments", name: "Customer Comments"],
            [ value: "qty", name: "Qty"],
            [ value: "price", name: "Price"],
            [ value: "firstname", name: "First name"],
            [ value: "lastname", name: "Last name"],
            [ value: "email", name: "Email"],
            [ value: "address_1", name: "Address 1"],
            [ value: "address_2", name: "Address 2"],
            [ value: "city", name: "City"],
            [ value: "state", name: "State"],
            [ value: "postcode", name: "Postal Code"],
            [ value: "country", name: "Country"],
            [ value: "method", name: "Shipping Method"]
        ]
=end
        if csvmap.order_map.nil?
          @result["order"]["settings"] = Hash.new
        else
          @result["order"]["settings"] = csv.order_map
        end
        if csvmap.product_map.nil?
          @result["product"]["settings"] = Hash.new
        else
          @result["product"]["settings"] = csv.product_map
        end

        csv_directory = "uploads/csv"
        if ["both","order"].include?(params[:type])
          order_file_path = File.join(csv_directory, "#{@store.id}.order.csv")
          if File.exists? order_file_path
            # read 4 mb data
            order_file_data = IO.read(order_file_path,4194304)
            @result["order"]["data"] = order_file_data
          end
        end
        if ["both","product"].include?(params[:type])
          product_file_path = File.join(csv_directory, "#{@store.id}.product.csv")
          if File.exists? product_file_path
            product_file_data = IO.read(product_file_path,4194304)
            @result["product"]["data"] = product_file_data
          end
        end
      else
        @result["status"] = false
      end
    end

    respond_to do |format|
      format.json { render json: @result}
    end
  end

  def changestorestatus
    @result = Hash.new
    @result['status'] = true
    params['_json'].each do|store|
      @store = Store.find(store["id"])
      @store.status = store["status"]
      if !@store.save
        @result['status'] = false
      end
    end


    respond_to do |format|
        format.html # show.html.erb
        format.json { render json: @result }
    end
  end

  def editstore
  end

  def duplicatestore

    @result = Hash.new
    @result['status'] = true
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


    respond_to do |format|
        format.html # show.html.erb
        format.json { render json: @result }
    end
  end

  def deletestore
    @result = Hash.new
    @result['status'] = false
    params['_json'].each do|store|
      @store = Store.find(store["id"])
      if @store.deleteauthentications && @store.destroy
        @result['status'] = true
      end
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
end
