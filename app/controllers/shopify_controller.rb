class ShopifyController < ApplicationController
  before_filter :groovepacker_authorize!, :except => [:auth, :callback, :preferences, :help, :complete, :get_auth, :recurring_application_fee, :recurring_tenant_charges, :finalize_payment]
  skip_before_filter  :verify_authenticity_token
  # {
  #  "code"=>"58a883f4bb36e4e953431549abff383c", 
  #  "hmac"=>"0542bc2a50645289f1af07d4f85f3ebe9883af6ab402ea24f2c1c1bbac57f8c8", 
  #  "shop"=>"groovepacker-dev-shop.myshopify.com", 
  #  "signature"=>"1a90fbf68c06ba55d8d7f6a7740e4a79", 
  #  "timestamp"=>"1428928120", 
  #  "id"=>"1" 
  # }
  def auth
    if cookies[:tenant_name].blank?
      session = ShopifyAPI::Session.new(params["shop"])
      token = session.request_token(params.except(:id))
      @result = true if token.present?
      subsc = Subscription.where(shopify_shop_name: params["shop"].split('.')[0]).last
      if $redis.get("#{params["shop"]}_existing_store").present?
        update_plan(token, params["shop"])
      else  
        one_time_fee(token, params["shop"])
      end
    else  
      #@tenant_name, @is_admin = params[:tenant_name].split('&')
      @tenant_name = cookies[:tenant_name]
      @store_id = cookies[:store_id]
      Apartment::Tenant.switch(@tenant_name)
      store = Store.find(@store_id) rescue nil
      @shopify_credential = store.shopify_credential
      session = ShopifyAPI::Session.new(@shopify_credential.shop_name + ".myshopify.com")
      @result = false
      begin
        @result = true if @shopify_credential.update_attributes({
                                                                  access_token: session.request_token(params.except(:id))
                                                                })
        destroy_cookies
      rescue Exception => ex
        @result = false
      end
    end
  end

  def update_plan(token, shop_name)
    price = $redis.get("#{shop_name}_plan_id").split("-")[1].to_f
    tenant_name = $redis.get("#{shop_name}_tenant")
    Apartment::Tenant.switch tenant_name
    session = ShopifyAPI::Session.new(shop_name, token)
    ShopifyAPI::Base.activate_session(session)
    recurring_application_charge = ShopifyAPI::RecurringApplicationCharge.new
    recurring_application_charge.attributes = {
            "name" =>  "Tenant plan charges",
            "price" => price + 10,
            "return_url" => "http://#{tenant_name}.#{ENV["SHOPIFY_REDIRECT_HOST"]}/shopify/finalize_payment?shop_name=#{shop_name}", 
            "trial_days" => 0,
            "terms" => "10 out of 2"}
    recurring_application_charge.test = true if ENV['SHOPIFY_BILLING_IN_TEST']=="true"
    if recurring_application_charge.save
      redirect_to recurring_application_charge.confirmation_url
    end
  end

  def one_time_fee(token, shop_name)
    token_params = $redis.get(shop_name)
    $redis.set("#{params["shop_name"]}_ready_to_be_deployed", false)
    session = ShopifyAPI::Session.new(shop_name, token)
    ShopifyAPI::Base.activate_session(session)
    app_charges = ShopifyAPI::ApplicationCharge.new()
    app_charges.attributes = {
        "name" => "One Time Charge for Deployment",
        "price" => 500.0,
        "return_url" => "http://admin.#{ENV["SHOPIFY_REDIRECT_HOST"]}/shopify/recurring_tenant_charges?shop_name=#{shop_name}"
    }
    app_charges.test = true if ENV['SHOPIFY_BILLING_IN_TEST']=="true"
    if app_charges.save
      redirect_to app_charges.attributes["confirmation_url"]
    end
  end

  def recurring_tenant_charges
    otf = ShopifyAPI::ApplicationCharge.find(params["charge_id"])
    otf.status == "accepted" ? otf.activate : redirect(select_plan_subscriptions_path)
    price = $redis.get("#{params["shop_name"]}_plan_id").split("-")[1].to_f
    $redis.set("#{params['shop_name']}_otf", params["charge_id"])      #saf -> Recurring Shopify App Fee
    $redis.set("#{params["shop_name"]}_ready_to_be_deployed", false)
    token = $redis.get("#{params['shop_name']}")
    session = ShopifyAPI::Session.new(params["shop_name"], token)
    ShopifyAPI::Base.activate_session(session)
    recurring_application_charge = ShopifyAPI::RecurringApplicationCharge.new
    recurring_application_charge.attributes = {
            "name" =>  "Tenant and App charges",
            "price" => price + 10,
            "return_url" => "http://admin.#{ENV["SHOPIFY_REDIRECT_HOST"]}/shopify/finalize_payment?shop_name=#{params['shop_name']}", 
            "trial_days" => 30,
            "terms" => "10 out of 2"}
    recurring_application_charge.test = true if ENV['SHOPIFY_BILLING_IN_TEST']=="true"
    if recurring_application_charge.save
      redirect_to recurring_application_charge.confirmation_url
    end
  end


  def finalize_payment
    tenant_fee = ShopifyAPI::RecurringApplicationCharge.find(params["charge_id"])
    tenant_fee.activate if tenant_fee.status == "accepted" 
    existing_store = $redis.get("#{params['shop_name']}_existing_store")
    plan = $redis.get("#{params["shop_name"]}_plan_id").split(".")[0] rescue nil
    $redis.del("#{params["shop_name"]}_plan_id")
    $redis.del("#{params["shop_name"]}_existing_store")
    $redis.set("#{params['shop_name']}_rtc", params["charge_id"])
    if existing_store.present?
      tenant = Tenant.find_by_name(Apartment::Tenant.current)
      tenant.update_attribute(:is_modified, true)
      subsc = Subscription.find_by_tenant_name("jamiin")
      tenant_data = subsc.tenant_data.split("-")
      access_restriction =  AccessRestriction.last
      access_restriction.update_attributes(:num_shipments => tenant_data[1], :num_users => tenant_data[2], :num_import_sources => tenant_data[3])
      subsc.update_attributes(:subscription_plan_id => plan, :tenant_charge_id => params["charge_id"], :shopify_payment_token => nil, :tenant_data => nil)
      if tenant_fee.status == "declined"
        render "payment_failed" and return
      else
        render "updated_plan" and return
      end
    else  
      response_status = check_if_paid_all_the_charges
      unless response_status
        render "payment_failed" and return
      end
    end
  end

  # hmac=d43d3f1d1ef5453bcdc62909e8db267ca95dc524dd3c61871c051abd338606a1&
  # shop=groovepacker-dev-shop.myshopify.com&
  # signature=9496a95477ede166870e8f08da1b4526&
  # timestamp=1430733874
  def callback
    # redirect to admin page with the shopify and with groove-solo plan
    # get shop name
    @shop_name = get_shop_name(params[:shop]) rescue nil
    $redis.set(@shop_name, params)
    #redirect_to subscriptions_path(plan_id: 'groove-solo', shopify: shop_name )
  end

  def disconnect
    store = Store.find(params[:id])
    @shopify_credential = store.shopify_credential
    session = ShopifyAPI::Session.new(@shopify_credential.shop_name + ".myshopify.com")
    if @shopify_credential.update_attributes({
                                               access_token: nil
                                             })
      render status: 200, json: 'disconnected'
    else
      render status: 304, json: 'not disconnected'
    end
  end

  def preferences
  end

  def help
  end

  def complete
  end

  def update_customer_plan
    tenant_name = Apartment::Tenant.current
    @tenant = Tenant.find_by_name(tenant_name)
    subsc = @tenant.subscription
    shop_name = subsc.shopify_shop_name
    $redis.set("#{shop_name}.myshopify.com_tenant", @tenant.name)
    $redis.set("#{shop_name}.myshopify.com_existing_store", true)
    $redis.set("#{shop_name}.myshopify.com_plan_id", "GROOV-#{subsc.tenant_data.split("-")[0]}") rescue nil
    params["shop_name"] = shop_name
    if subsc.shopify_payment_token == params["one_time_token"] && subsc.tenant_data.present? 
      redirect_to get_auth
    else
      redirect_to invalid_request_shopify_index_path
    end
  end

  def invalid_request

  end

  def get_auth
    result = {}
    destroy_cookies rescue nil
    session = ShopifyAPI::Session.new("#{params["shop_name"]}.myshopify.com")
    scope = [ "read_orders", "write_orders", "read_products", "write_products"]
    result[:permission_url] = session.create_permission_url(scope, "http://admin.#{ENV["SHOPIFY_REDIRECT_HOST"]}/shopify/auth")
    if @tenant.present?
      return result[:permission_url]
    else
      $redis.del("#{params["shop"]}_existing_store")
      $redis.set("#{params["shop_name"]}.myshopify.com_plan_id", params["name"])
      render json: result
    end
  end

  private
  def get_shop_name(shop_name)
    (shop_name.split(".").length == 3) ? shop_name.split(".").first : nil
  end

  def destroy_cookies
    cookies[:tenant_name] = {:value => nil , :domain => :all, :expires => Time.now+2.seconds}
    cookies[:store_id] = {:value => nil , :domain => :all, :expires => Time.now+2.seconds}
  end

  def check_if_paid_all_the_charges
    token = $redis.get(params["shop_name"])
    session = ShopifyAPI::Session.new(params["shop_name"], token)
    ShopifyAPI::Base.activate_session(session)
    otf = ShopifyAPI::ApplicationCharge.find($redis.get("#{params['shop_name']}_otf")).attributes["status"] rescue nil
    rtc = ShopifyAPI::RecurringApplicationCharge.find($redis.get("#{params['shop_name']}_rtc")).attributes["status"] rescue nil
    resp_status = (otf=="active" and rtc=="active")
    if resp_status
      $redis.set("#{params["shop_name"]}_ready_to_be_deployed", true)
    end
    return resp_status
  end
end