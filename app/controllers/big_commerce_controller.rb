class BigCommerceController < ApplicationController
  before_filter :groovepacker_authorize!, :only => [:check_connection, :disconnect]
  before_filter :find_store, :only => [:check_connection, :disconnect]

  def setup
    # redirect to admin page with the big-commerce and with groove-solo plan
    # get shop name
    @store_user_email = cookies[:store_user_email] rescue ""
    @shop_name = get_shop_name(params[:shop])
    flash[:notice] = "Please try to complete setup process in 15 minutes. Otherwise BigCommerce access-token may expire."
    #redirect_to subscriptions_path(plan_id: 'groove-solo', bigcommerce: shop_name )
  end

  def bigcommerce
    @auth_hash = generate_access_token
    key = "groovehacks:bigcommerce:session"
    app_session = $redis.get(key)
    app_session = JSON.parse(app_session)
    unless app_session["tenant"].blank?
      @store_id = app_session["store_id"] 
      Apartment::Tenant.switch(app_session["tenant"])
      update_bc_credentials
      $redis.del(key)
      redirect_to big_commerce_complete_path
    else
      store_auth_values_in_cookies
      $redis.del(key)
      redirect_to big_commerce_setup_path(:shop => "#{bc_store_name}.mybigcommerce.com")
    end
    # unless cookies[:tenant_name].blank?
    #   Apartment::Tenant.switch(cookies[:tenant_name])
    #   update_bc_credentials
    #   redirect_to big_commerce_complete_path
    # else
    #   store_auth_values_in_cookies
    #   redirect_to big_commerce_setup_path(:shop => "#{bc_store_name}.mybigcommerce.com")
    # end
  end

  def uninstall
    render json: {:status => 200}
  end

  def load
    #render json: {:status => 200}
  end

  def login
  end
  
  def remove
    render json: {:status => 200}
  end

  def check_connection
    response = BigCommerce::BigCommerceService.new(store: @store).check_connection

    render json: response
  end

  def complete
  end

  def disconnect
    store_credentials = @store.big_commerce_credential
    if store_credentials.update_attributes(:store_hash => nil, :access_token => nil)
      render status: 200, json: 'disconnected'
    else
      render status: 304, json: 'not disconnected'
    end
  end

  private
    def bc_store_name
      params['context'].split("/").last rescue 'bcstore'
    end

    def get_shop_name(shop_name)
      (shop_name.split(".").length == 3) ? shop_name.split(".").first : nil
    end

    def generate_access_token
      url = 'https://login.bigcommerce.com/oauth2/token'
      body_attrs = { client_id: ENV['BC_CLIENT_ID'], client_secret: ENV['BC_CLIENT_SECRET'], code: params[:code], scope: params[:scope], grant_type: :authorization_code, redirect_uri: "https://#{ENV['BC_CALLBACK_HOST']}/bigcommerce/callback", context: params[:context] }
       begin
        response = HTTParty.post('https://login.bigcommerce.com/oauth2/token', body: body_attrs.to_json, headers: { "X-Auth-Client" => ENV['BC_CLIENT_ID'], "Content-Type" => "application/json", "Accept" => "application/json" })
        return response
      rescue Exception => ex
        
        return false
      end
    end

    def update_bc_credentials
      @bigcommerce_credentials = BigCommerceCredential.find_by_store_id(@store_id)
      @bigcommerce_credentials.access_token = @auth_hash["access_token"] rescue nil
      @bigcommerce_credentials.store_hash = @auth_hash["context"] rescue nil
      @bigcommerce_credentials.save
      #cookies.delete(:tenant_name)
      #cookies.delete(:store_id)


      # cookies[:tenant_name] = {:value => nil , :domain => :all, :expires => Time.now+2.seconds}
      # cookies[:store_id] = {:value => nil , :domain => :all, :expires => Time.now+2.seconds}
    end

    def store_auth_values_in_cookies
      store_user_email = @auth_hash['user']['email'] rescue ""  
      store_access_token = @auth_hash["access_token"] rescue ""
      store_context = @auth_hash["context"] rescue ""
      session_key = "groovehacks:bigcommerce:session"
      stored_session = JSON.generate({'tenant' => Apartment::Tenant.current, 'store_user_email' => store_user_email, 
        'store_access_token' => store_access_token, 'store_context' => store_context})
      $redis.set(session_key, stored_session.to_s)
      $redis.expire(session_key, 300)

      # cookies[:store_user_email] = {:value => store_user_email , :domain => :all, :expires => Time.now+15.minutes}
      # cookies[:store_access_token] = {:value => store_access_token , :domain => :all, :expires => Time.now+15.minutes}
      # cookies[:store_context] = {:value => store_context , :domain => :all, :expires => Time.now+15.minutes}
    end

    def find_store
      @store = Store.find_by_id(params[:store_id])
    end
end
