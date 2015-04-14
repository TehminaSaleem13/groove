class Store < ActiveRecord::Base
  attr_accessible :name, :order_date, :status, :store_type, :inventory_warehouse
  has_many :orders
  has_many :products
  has_one :magento_credentials
  has_one :ebay_credentials
  has_one :amazon_credentials
  has_one :shipstation_credential
  has_one :shipstation_rest_credential
  has_one :shipworks_credential
  has_one :shopify_credential

  belongs_to :inventory_warehouse

  validates_presence_of :name
  validates_uniqueness_of :name
  validates_presence_of :inventory_warehouse

  before_create 'Store.can_create_new?'

  def get_store_credentials
  	@result = Hash.new
    @result['status'] =false
  	if self.store_type == 'Amazon'
  		@credentials = AmazonCredentials.where(:store_id => self.id)
  		if !@credentials.nil? && @credentials.length > 0
  			@result['amazon_credentials'] = @credentials.first
        @result['status'] =true
  		end
  	end
  	if self.store_type == 'Ebay'
  		@credentials = EbayCredentials.where(:store_id => self.id)

  		if !@credentials.nil? && @credentials.length > 0
  			@result['ebay_credentials'] = @credentials.first
        @result['status'] =true
  		end
  	end
  	if self.store_type == 'Magento'
  		@credentials = MagentoCredentials.where(:store_id => self.id)
  		if !@credentials.nil? && @credentials.length > 0
  			@result['magento_credentials'] = @credentials.first
        @result['status'] =true
  		end
  	end
    if self.store_type == 'Shipstation'
      @credentials = ShipstationCredential.where(:store_id => self.id)
      if !@credentials.nil? && @credentials.length > 0
        @result['shipstation_credentials'] = @credentials.first
        @result['status'] =true
      end
    end
    if self.store_type == 'Shipstation API 2'
      @credentials = ShipstationRestCredential.where(:store_id => self.id)
      if !@credentials.nil? && @credentials.length > 0
        @result['shipstation_rest_credentials'] = @credentials.first
        @result['shipstation_rest_credentials']['gp_ready_tag_name'] = @credentials.first.gp_ready_tag_name
        @result['shipstation_rest_credentials']['gp_imported_tag_name'] = @credentials.first.gp_imported_tag_name
        @result['status'] =true
      end
    end
    if self.store_type == 'Shipworks'
      @result['shipworks_credentials'] = shipworks_credential
      @result['shipworks_hook_url'] = "https://"+Apartment::Database.current_tenant+"."+ENV['HOST_NAME']+"/orders/import_shipworks?auth_token="
      @result['status'] =true
    end
    if self.store_type == 'Shopify'
      @result['shopify_credentials'] = shopify_credential
      if shopify_credential.access_token.nil?
        shopify_handle = Groovepacker::ShopifyRuby::Utilities.new(shopify_credential)
        @result['shopify_permission_url'] = shopify_handle.permission_url(Apartment::Database.current_tenant)
      end
      @result['status'] =true
    end
  	@result
  end

  def deleteauthentications
    @result = true
    if self.store_type == 'Amazon'
      @credentials = AmazonCredentials.where(:store_id => self.id)
    end
    if self.store_type == 'Ebay'
      @credentials = EbayCredentials.where(:store_id => self.id)
    end
    if self.store_type == 'Magento'
      @credentials = MagentoCredentials.where(:store_id => self.id)
    end
    if self.store_type == 'Shipstation'
      @credentials = ShipstationCredential.where(:store_id => self.id)
    end
    if self.store_type == 'Shopify'
      @credentials = ShopifyCredential.where(:store_id => self.id)
    end
    if !@credentials.nil? && @credentials.length > 0
      if !(@credentials.first.destroy)
        @result= false
      end
    end
    @result
  end

  def dupauthentications(id)
    @result = true
    if self.store_type == 'Amazon'
      @credentials = AmazonCredentials.where(:store_id => id)
      if !@credentials.nil? && @credentials.length > 0
        @newcredentials = AmazonCredentials.new 
        @newcredentials = @credentials.first.dup
        @newcredentials.store_id = self.id
        if !@newcredentials.save
          @result = false
        end
      end
    end
    if self.store_type == 'Ebay'
      @credentials = EbayCredentials.where(:store_id => id)
      if !@credentials.nil? && @credentials.length > 0
        @newcredentials = EbayCredentials.new 
        @newcredentials = @credentials.first.dup
        @newcredentials.store_id = self.id
        if !@newcredentials.save
          @result = false
        end
      end
    end
    if self.store_type == 'Magento'
      @credentials = MagentoCredentials.where(:store_id => id)
      if !@credentials.nil? && @credentials.length > 0
        @newcredentials = MagentoCredentials.new 
        @newcredentials = @credentials.first.dup
        @newcredentials.store_id = self.id
        if !@newcredentials.save
          @result = false
        end
      end
    end
    if self.store_type == 'Shipstation'
      @credentials = ShipstationCredential.where(:store_id => id)
      if !@credentials.nil? && @credentials.length > 0
        @newcredentials = ShipstationCredential.new 
        @newcredentials = @credentials.first.dup
        @newcredentials.store_id = self.id
        if !@newcredentials.save
          @result = false
        end
      end
    end
    if self.store_type == 'Shipworks'
      result = false unless ShipworksCredential.create(auth_token: SecureRandom.base64(16), store: self)
    end
    @result
  end

  def get_signin_url
   ebaysession_resp = self.get_ebay_sessionid()
   if ebaysession_resp['GetSessionIDResponse']['Ack'] == "Success"
    session_id = ebaysession_resp['GetSessionIDResponse']['SessionID']
    if ENV['EBAY_SANDBOX_MODE'] == 'YES'
      @result['ebay_signin_url'] = "https://signin.sandbox.ebay.com/ws/eBayISAPI.dll?SignIn&RuName="+
        ENV['EBAY_RU_NAME']+"&SessID="+session_id
    else
      @result['ebay_signin_url'] = "https://signin.ebay.com/ws/eBayISAPI.dll?SignIn&RuName="+
        ENV['EBAY_RU_NAME']+"&SessID="+session_id
    end
    @result['ebay_signin_url_status'] = true
  else
    @result['ebay_signin_url'] = ebaysession_resp
    @result['ebay_signin_url_status'] = false      
   end
  end
  def get_ebay_signin_url
    require "net/http"
    require "uri"
    @result = Hash.new
    devName = ENV['EBAY_DEV_ID']
    appName = ENV['EBAY_APP_ID']
    certName = ENV['EBAY_CERT_ID']
    #authToken = 'AgAAAA**AQAAAA**aAAAAA**YD88Ug**nY+sHZ2PrBmdj6wVnY+sEZ2PrA2dj6wJnY+lDpOGowqdj6x9nY+seQ**llgCAA**AAMAAA**sMVS7bsvPTHE2O6w45xeuCrZKL/HBe71C0lkE3apOV6DeTJdF/AgncabtJkm/KrznQC+AzBB/jDVKpHnOkyVm6u5vWDK4cG2lgvdKOCp67YsJmmWHMZu72dGMGvlvdwghPKQYbldFSfJRNQvTriekNSaaSkZMXigVA9S3Aqf8kYae12GFmg1d0eTMH55YWu5C5fjRQTxQRqMWSUI1czgNkl9ENK45D3Hzuo+XWegvs3NVzlSG85WIhRSrItyeUzaOOiY9TpPfb129Bke23+5a6Z0WwV7MrMWKLHhLxzIOc3tvy2zMzLj9UW2avx5JEWbgDe08MmeN4WgOGQGP0+5Zi8YWjqqhLtgDuEpA0W2rXRoONtRPM7nx8HDWCAMAToCz52pQS/No5tCArf3v+9R2fNnTltO/paVzFdSZOXzV2htODtqnasTKrgW4iNd9SO1X7Bcj4dOHtIy64eQCItx1A137mM/tqY5/jUfSJlnL3qkD/xPfCrKFiVbBQUS4nBjNTRVPLM0DpuBhtd+EI3z3LEUuXRwjHMm5Gh3CLfBXG444CV7zpT1m3i1Po1qHfjipm0OIPoCaTm/lad3QUak3WC+E85QYicJHFXBMKS/XjsPSqxxFbnywys+39hiRHpkFzxEFGEQOfBLTKHv41PgAB4DoopGf1kD6AeJZdlu2OVWv05HawYFfPysOTf9oPbXJt9yL/2LJ46qzT9w4s35NgNHj8tn6QojLvNfc8fOguF17YUioYiUFhEDNd9txYmt'
    ruName =   ENV['EBAY_RU_NAME']
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
    req.add_field("X-EBAY-API-CALL-NAME", "GetSessionID")

    req.body = '<?xml version="1.0" encoding="utf-8"?>'+
                '<GetSessionIDRequest xmlns="urn:ebay:apis:eBLBaseComponents">'+
                "<RuName>#{ruName}</RuName>"+
                '</GetSessionIDRequest>'

    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    res = http.start do |http_runner|
      http_runner.request(req)
    end
  ebaysession_resp = MultiXml.parse(res.body)
  if ebaysession_resp['GetSessionIDResponse']['Ack'] == "Success"
    session_id = ebaysession_resp['GetSessionIDResponse']['SessionID']
    if ENV['EBAY_SANDBOX_MODE'] == 'YES'
    @result['ebay_signin_url'] = "https://signin.sandbox.ebay.com/ws/eBayISAPI.dll?SignIn&RuName="+ENV['EBAY_RU_NAME']+"&SessID="+session_id
    else
    @result['ebay_signin_url'] = "https://signin.ebay.com/ws/eBayISAPI.dll?SignIn&RuName="+ENV['EBAY_RU_NAME']+"&SessID="+session_id
    end
    @result['ebay_signin_url_status'] = true
    @result['ebay_sessionid'] = session_id
  else
    @result['ebay_signin_url'] = ebaysession_resp
    @result['ebay_signin_url_status'] = false      
   end
    return @result
  end

  def self.can_create_new?
    unless AccessRestriction.order("created_at").last.nil?
      self.where("store_type != 'system'").count < AccessRestriction.order("created_at").last.num_import_sources
    end
  end
end
