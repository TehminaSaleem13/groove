# frozen_string_literal: true

class Store < ActiveRecord::Base
  # attr_accessible :name, :order_date, :status, :store_type, :inventory_warehouse, :inventory_warehouse_id, :split_order, :troubleshooter_option, :on_demand_import_v2, :regular_import_v2
  has_many :orders
  has_many :products
  has_many :origin_stores, foreign_key: :store_id
  has_one :magento_credentials
  has_one :ebay_credentials
  has_one :amazon_credentials
  has_one :shipstation_credential
  has_one :shipstation_rest_credential
  has_one :shipworks_credential
  has_one :shopify_credential
  has_one :ftp_credential
  has_one :big_commerce_credential
  has_one :magento_rest_credential
  has_one :shipping_easy_credential
  has_one :teapplix_credential
  has_one :shippo_credential

  belongs_to :inventory_warehouse

  validates_presence_of :name
  validates_uniqueness_of :name
  validates_presence_of :inventory_warehouse

  include StoresHelper
  include AhoyEvent
  after_commit :log_events

  before_create :check_for_new_store

  def check_for_new_store
    self.class.can_create_new?
  end

  def log_events
    if saved_changes.present? && saved_changes.keys != ['updated_at']
      track_changes(title: 'Store Settings Changed', tenant: Apartment::Tenant.current,
                    username: User.current.try(:username) || 'GP App', object_id: id, changes: saved_changes)
    end
  end

  def ensure_warehouse?
    if inventory_warehouse.nil?
      self.inventory_warehouse = InventoryWarehouse.where(is_default: true).first
      save
    end
    true
  end

  def get_store_credentials
    @result = {}
    @result['status'] = false
    if store_type == 'Amazon'
      @credentials = AmazonCredentials.where(store_id: id)
      if !@credentials.nil? && !@credentials.empty?
        @result['amazon_credentials'] = @credentials.first
        @result['status'] = true
      end
    end
    if store_type == 'Ebay'
      @credentials = EbayCredentials.where(store_id: id)

      if !@credentials.nil? && !@credentials.empty?
        @result['ebay_credentials'] = @credentials.first
        @result['status'] = true
      end
    end
    if store_type == 'Magento'
      @credentials = MagentoCredentials.where(store_id: id)
      if !@credentials.nil? && !@credentials.empty?
        @result['magento_credentials'] = @credentials.first
        @result['status'] = true
      end
    end
    if store_type == 'Teapplix'
      @credential = TeapplixCredential.find_by_store_id(id)
      if @credential
        @result['teapplix_credential'] = @credential
        @result['status'] = true
      end
    end
    if store_type == 'Magento API 2'
      @credentials = MagentoRestCredential.where(store_id: id)
      if !@credentials.nil? && !@credentials.empty?
        @result['magento_rest_credential'] = @credentials.first
        @result['status'] = true
      end
    end
    if store_type == 'Shipstation'
      @credentials = ShipstationCredential.where(store_id: id)
      if !@credentials.nil? && !@credentials.empty?
        @result['shipstation_credentials'] = @credentials.first
        @result['status'] = true
      end
    end
    if store_type == 'Shipstation API 2'
      @credentials = ShipstationRestCredential.where(store_id: id)
      if !@credentials.nil? && !@credentials.empty?
        @result['shipstation_rest_credentials'] = @credentials.first
        @result['shipstation_rest_credentials'] = @result['shipstation_rest_credentials'].attributes.merge('gp_ready_tag_name' => @credentials.first.gp_ready_tag_name, 'gp_imported_tag_name' => @credentials.first.gp_imported_tag_name, 'gp_scanned_tag_name' => @credentials.first.gp_scanned_tag_name)
        @result['status'] = true
      end
    end
    if store_type == 'ShippingEasy'
      @credentials = shipping_easy_credential
      unless @credentials.nil?
        @result['shipping_easy_credentials'] = @credentials
        @result['status'] = true
      end
    end
    if store_type == 'Shipworks'
      @result['shipworks_credentials'] = shipworks_credential
      @result['shipworks_hook_url'] = 'https://' + Apartment::Tenant.current + '.' + ENV['SITE_HOST'] + '/orders/import_shipworks?auth_token='
      @result['status'] = true
    end
    if self.store_type == 'Shippo'
      @credentials = ShippoCredential.where(:store_id => self.id)
      if !@credentials.nil? && @credentials.length > 0
        @result['shippo_credentials'] = @credentials.first
        @result['status'] =true
      end
    end
    if store_type == 'Shopify'
      @result['shopify_credentials'] = shopify_credential
      @result['shopify_locations'] = shopify_credential.locations
      if shopify_credential.access_token.in? [nil, 'null', 'undefined']
        shopify_handle = Groovepacker::ShopifyRuby::Utilities.new(shopify_credential)
        @result['shopify_permission_url'] = shopify_handle.permission_url(Apartment::Tenant.current)
      end
      @result['status'] = true
    end
    if store_type == 'BigCommerce'
      @result['big_commerce_credentials'] = big_commerce_credential
      @result['bigcommerce_permission_url'] = ENV['BC_APP_URL']
      @result['status'] = true
    end
    if store_type == 'CSV'
      @credentials = FtpCredential.where(store_id: id)
      unless @credentials.nil? || @credentials.empty?
        @result['ftp_credentials'] = @credentials.first
        @result['status'] = true
      end
    end
    @result
  end

  def deleteauthentications
    @result = true
    @credentials = AmazonCredentials.where(store_id: id) if store_type == 'Amazon'
    @credentials = EbayCredentials.where(store_id: id) if store_type == 'Ebay'
    @credentials = MagentoCredentials.where(store_id: id) if store_type == 'Magento'
    @credentials = ShipstationCredential.where(store_id: id) if store_type == 'Shipstation'
    @credentials = ShopifyCredential.where(store_id: id) if store_type == 'Shopify'
    if !@credentials.nil? && !@credentials.empty?
      @result = false unless @credentials.first.destroy
    end
    @result
  end

  def dupauthentications(id)
    @result = true
    if store_type == 'Amazon'
      @credentials = AmazonCredentials.where(store_id: id)
      if !@credentials.nil? && !@credentials.empty?
        @newcredentials = AmazonCredentials.new
        @newcredentials = @credentials.first.dup
        @newcredentials.store_id = self.id
        @result = false unless @newcredentials.save
      end
    end
    if store_type == 'Ebay'
      @credentials = EbayCredentials.where(store_id: id)
      if !@credentials.nil? && !@credentials.empty?
        @newcredentials = EbayCredentials.new
        @newcredentials = @credentials.first.dup
        @newcredentials.store_id = self.id
        @result = false unless @newcredentials.save
      end
    end
    if store_type == 'Magento'
      @credentials = MagentoCredentials.where(store_id: id)
      if !@credentials.nil? && !@credentials.empty?
        @newcredentials = MagentoCredentials.new
        @newcredentials = @credentials.first.dup
        @newcredentials.store_id = self.id
        @result = false unless @newcredentials.save
      end
    end
    if store_type == 'Shipstation'
      @credentials = ShipstationCredential.where(store_id: id)
      if !@credentials.nil? && !@credentials.empty?
        @newcredentials = ShipstationCredential.new
        @newcredentials = @credentials.first.dup
        @newcredentials.store_id = self.id
        @result = false unless @newcredentials.save
      end
    end
    if store_type == 'Shipworks'
      result = false unless ShipworksCredential.create(auth_token: SecureRandom.base64(16), store: self)
    end
    @result
  end

  def get_signin_url
    ebaysession_resp = get_ebay_sessionid
    if ebaysession_resp['GetSessionIDResponse']['Ack'] == 'Success'
      session_id = ebaysession_resp['GetSessionIDResponse']['SessionID']
      @result['ebay_signin_url'] = if ENV['EBAY_SANDBOX_MODE'] == 'YES'
                                     'https://signin.sandbox.ebay.com/ws/eBayISAPI.dll?SignIn&RuName=' +
                                       ENV['EBAY_RU_NAME'] + '&SessID=' + session_id
                                   else
                                     'https://signin.ebay.com/ws/eBayISAPI.dll?SignIn&RuName=' +
                                       ENV['EBAY_RU_NAME'] + '&SessID=' + session_id
                                   end
      @result['ebay_signin_url_status'] = true
    else
      @result['ebay_signin_url'] = ebaysession_resp
      @result['ebay_signin_url_status'] = false
    end
  end

  def get_ebay_signin_url
    require 'net/http'
    require 'uri'
    @result = {}
    devName = ENV['EBAY_DEV_ID']
    appName = ENV['EBAY_APP_ID']
    certName = ENV['EBAY_CERT_ID']
    # authToken = 'AgAAAA**AQAAAA**aAAAAA**YD88Ug**nY+sHZ2PrBmdj6wVnY+sEZ2PrA2dj6wJnY+lDpOGowqdj6x9nY+seQ**llgCAA**AAMAAA**sMVS7bsvPTHE2O6w45xeuCrZKL/HBe71C0lkE3apOV6DeTJdF/AgncabtJkm/KrznQC+AzBB/jDVKpHnOkyVm6u5vWDK4cG2lgvdKOCp67YsJmmWHMZu72dGMGvlvdwghPKQYbldFSfJRNQvTriekNSaaSkZMXigVA9S3Aqf8kYae12GFmg1d0eTMH55YWu5C5fjRQTxQRqMWSUI1czgNkl9ENK45D3Hzuo+XWegvs3NVzlSG85WIhRSrItyeUzaOOiY9TpPfb129Bke23+5a6Z0WwV7MrMWKLHhLxzIOc3tvy2zMzLj9UW2avx5JEWbgDe08MmeN4WgOGQGP0+5Zi8YWjqqhLtgDuEpA0W2rXRoONtRPM7nx8HDWCAMAToCz52pQS/No5tCArf3v+9R2fNnTltO/paVzFdSZOXzV2htODtqnasTKrgW4iNd9SO1X7Bcj4dOHtIy64eQCItx1A137mM/tqY5/jUfSJlnL3qkD/xPfCrKFiVbBQUS4nBjNTRVPLM0DpuBhtd+EI3z3LEUuXRwjHMm5Gh3CLfBXG444CV7zpT1m3i1Po1qHfjipm0OIPoCaTm/lad3QUak3WC+E85QYicJHFXBMKS/XjsPSqxxFbnywys+39hiRHpkFzxEFGEQOfBLTKHv41PgAB4DoopGf1kD6AeJZdlu2OVWv05HawYFfPysOTf9oPbXJt9yL/2LJ46qzT9w4s35NgNHj8tn6QojLvNfc8fOguF17YUioYiUFhEDNd9txYmt'
    ruName = ENV['EBAY_RU_NAME']
    url = if ENV['EBAY_SANDBOX_MODE'] == 'YES'
            'https://api.sandbox.ebay.com/ws/api.dll'
          else
            'https://api.ebay.com/ws/api.dll'
          end
    url = URI.parse(url)

    req = Net::HTTP::Post.new(url.path)
    req.add_field('X-EBAY-API-REQUEST-CONTENT-TYPE', 'text/xml')
    req.add_field('X-EBAY-API-COMPATIBILITY-LEVEL', '675')
    req.add_field('X-EBAY-API-DEV-NAME', devName)
    req.add_field('X-EBAY-API-APP-NAME', appName)
    req.add_field('X-EBAY-API-CERT-NAME', certName)
    req.add_field('X-EBAY-API-SITEID', 0)
    req.add_field('X-EBAY-API-CALL-NAME', 'GetSessionID')

    req.body = '<?xml version="1.0" encoding="utf-8"?>' \
               '<GetSessionIDRequest xmlns="urn:ebay:apis:eBLBaseComponents">' \
               "<RuName>#{ruName}</RuName>" \
               '</GetSessionIDRequest>'

    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    res = http.start do |http_runner|
      http_runner.request(req)
    end
    ebaysession_resp = MultiXml.parse(res.body)
    if ebaysession_resp['GetSessionIDResponse']['Ack'] == 'Success'
      session_id = ebaysession_resp['GetSessionIDResponse']['SessionID']
      if ENV['EBAY_SANDBOX_MODE'] == 'YES'
        @result['ebay_signin_url'] = 'https://signin.sandbox.ebay.com/ws/eBayISAPI.dll?SignIn&RuName=' + ENV['EBAY_RU_NAME'] + '&SessID=' + session_id
      else
        @result['ebay_signin_url'] = 'https://signin.ebay.com/ws/eBayISAPI.dll?SignIn&RuName=' + ENV['EBAY_RU_NAME'] + '&SessID=' + session_id
      end
      @result['ebay_signin_url_status'] = true
      @result['ebay_sessionid'] = session_id
    else
      @result['ebay_signin_url'] = ebaysession_resp
      @result['ebay_signin_url_status'] = false
    end
    @result
  end

  def self.can_create_new?
    unless AccessRestriction.order('created_at').last.nil?
      where("store_type != 'system'").count < AccessRestriction.order('created_at').last.num_import_sources
    end
  end

  def create_store_with_defaults(store_type)
    bc_store_count = Store.all.map(&:store_type).count(store_type)
    self.name = "#{store_type}-#{bc_store_count + 1}"
    self.store_type = store_type
    self.status = true
    self.inventory_warehouse_id = get_default_warehouse_id
    self.auto_update_products = false
    self.update_inv = true
    save
    self
  end

  def self.get_sucure_random_token(no_of_chars = 16)
    random_token = ''
    begin
      random_token = SecureRandom.base64(no_of_chars)
      includes_plus_sign = random_token.include?('+')
    end while includes_plus_sign
    random_token
  end

  def store_credential
    cred = case store_type
           when 'ShippingEasy'
             shipping_easy_credential
           when 'Shopify'
             shopify_credential
           when 'Shipstation API 2'
             shipstation_rest_credential
           when 'Shippo'
              shippo_credential
           end
  end
end
