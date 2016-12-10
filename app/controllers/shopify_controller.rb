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
      one_time_fee(token, params["shop"])
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

  def one_time_fee(token, shop_name)
    token_params = $redis.get(shop_name)
    $redis.set("#{params["shop_name"]}_ready_to_be_deployed", false)
    session = ShopifyAPI::Session.new(shop_name, token)
    ShopifyAPI::Base.activate_session(session)
    app_charges = ShopifyAPI::ApplicationCharge.new()
    app_charges.attributes = {
        "name" => "One Time Charge for Deployment",
        "price" => 500.0,
        "return_url" => "http://admin.localpacker.com/shopify/recurring_application_fee?shop_name=#{shop_name}"
    }
    app_charges.test = true if ENV['SHOPIFY_BILLING_IN_TEST']=="true"
    if app_charges.save
      redirect_to app_charges.attributes["confirmation_url"]
    end
  end


  def recurring_application_fee
    $redis.set("#{params['shop_name']}_otf", params["charge_id"])                    #otf -> One Time Fee
    $redis.set("#{params["shop_name"]}_ready_to_be_deployed", false)
    token = $redis.get("#{params['shop_name']}")
    session = ShopifyAPI::Session.new("groovepacker-dev-shop.myshopify.com", token)
    ShopifyAPI::Base.activate_session(session)
    recurring_application_charge = ShopifyAPI::RecurringApplicationCharge.new
    recurring_application_charge.attributes = {
            "name" =>  "Recurring App Charges",
            "price" => 10.00,
            "return_url" => "http://admin.localpacker.com/shopify/recurring_tenant_charges?shop_name=#{params['shop_name']}", 
            "trial_days" => 30,
            "terms" => "10 out of 2"}
    recurring_application_charge.test = true if ENV['SHOPIFY_BILLING_IN_TEST']=="true"
    if recurring_application_charge.save
      redirect_to recurring_application_charge.confirmation_url
    end
  end


  def recurring_tenant_charges
    price = $redis.get("#{params["shop_name"]}_plan_id").split("-")[1].to_f
    $redis.set("#{params['shop_name']}_rsaf", params["charge_id"])      #saf -> Recurring Shopify App Fee
    $redis.set("#{params["shop_name"]}_ready_to_be_deployed", false)
    token = $redis.get("#{params['shop_name']}")
    session = ShopifyAPI::Session.new("groovepacker-dev-shop.myshopify.com", token)
    ShopifyAPI::Base.activate_session(session)
    recurring_application_charge = ShopifyAPI::RecurringApplicationCharge.new
    recurring_application_charge.attributes = {
            "name" =>  "Tenant charges",
            "price" => price,
            "return_url" => "http://admin.localpacker.com/shopify/finalize_payment?shop_name=#{params['shop_name']}", 
            "trial_days" => 30,
            "terms" => "10 out of 2"}
    recurring_application_charge.test = true if ENV['SHOPIFY_BILLING_IN_TEST']=="true"
    $redis.del("#{params["shop_name"]}_plan_id")
    if recurring_application_charge.save
      redirect_to recurring_application_charge.confirmation_url
    end
  end


  def finalize_payment
    $redis.set("#{params['shop_name']}_rtc", params["charge_id"])      #saf -> Recurring Tenant Charges
    response_status = check_if_paid_all_the_charges
    unless response_status
      render "payment_failed" and return
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

  def get_auth
    $redis.set("#{params["shop_name"]}"+ ".myshopify.com_plan_id", params["name"])
    result = {}
    destroy_cookies rescue nil
    session = ShopifyAPI::Session.new(params["shop_name"] + ".myshopify.com")
    scope = [ "read_orders", "write_orders", "read_products", "write_products"]
    result[:permission_url] = session.create_permission_url(scope, "http://admin.#{ENV["SHOPIFY_REDIRECT_HOST"]}/shopify/auth")
    render json: result
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
    rsaf = ShopifyAPI::RecurringApplicationCharge.find($redis.get("#{params['shop_name']}_rsaf")).attributes["status"] rescue nil
    rtc = ShopifyAPI::RecurringApplicationCharge.find($redis.get("#{params['shop_name']}_rtc")).attributes["status"] rescue nil
    resp_status = (otf=="accepted" and rsaf=="accepted" and rtc=="accepted")
    if resp_status
      $redis.set("#{params["shop_name"]}_ready_to_be_deployed", true)
    end
    return resp_status
  end

end
