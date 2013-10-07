class StoreSettingsController < ApplicationController
  def storeslist
    @stores = Store.all

    respond_to do |format|
      format.json { render json: @stores}
    end
  end


  def getactivestores
    @result = Hash.new
    @result['status'] = true
    @result['stores'] = Store.where(:status=>'1')

    respond_to do |format|
      format.json { render json: @result}
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

        @amazon.productmarketplace_id = params[:productmarketplace_id]
        @amazon.productmerchant_id = params[:productmerchant_id]

        @amazon.import_products = params[:import_products]
        @amazon.import_images = params[:import_images]

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
        @result['storeid'] = @store.id
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

  def getebaysigninurl
    @store = Store.new
    @result = @store.get_ebay_signin_url
    session[:ebay_session_id] = @result['ebay_sessionid']
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
end


