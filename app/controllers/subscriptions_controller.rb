# frozen_string_literal: true

class SubscriptionsController < ApplicationController
  include PaymentsHelper
  include StoresHelper
  skip_before_action :verify_authenticity_token
  # before_action :check_tenant_name

  def new
    @subscription = Subscription.new
    plan_id = params[:plan_id]
    plan_price = begin
                   plan_id.split('-').last.to_i
                 rescue StandardError
                   0
                 end
    unless (plan_price >= 100) && (plan_price % 50 == 0)
      @plan_error = 'Please Select A Plan From The List'
      @plans = fetch_plans_info
      render(:select_plan) && return
    end
    @monthly_amount = plan_price * 100
    @annually_amount = (plan_price - (plan_price * 10 / 100)) * 12 * 100
  end

  def select_plan
    @plan_error ||= ''
    @plans = fetch_plans_info
  end

  def confirm_payment
    on_demand_logger = Logger.new("#{Rails.root}/log/subscription_logs.log")
    on_demand_logger.info('=========================================')
    log = { time: Time.zone.now, params: params }
    on_demand_logger.info(log)

    params[:tenant_name] = params[:tenant_name].gsub(/[^0-9A-Za-z]/, '')
    @subscription = create_subscription(params)
    if @subscription
      one_time_payment = params[:shop_name].blank? ? ENV['ONE_TIME_PAYMENT'] : 0
      one_time_payment = ENV['BC_ONE_TIME_PAYMENT'] if params[:shop_type] == 'BigCommerce'
      @subscription.save_with_payment(one_time_payment)
      check_status_and_render
    else
      render json: {
        valid: false,
        errors: @subscription.errors.full_messages.join(',')
      }
    end
  end

  def check_status_and_render
    if @subscription.status == 'completed'
      # for shopify create the store and send for authentication
      if params[:shop_name].blank?
        render json: response_for_successful_subscription
      else
        # switch tenant
        Apartment::Tenant.switch!(@subscription.tenant_name)
        # response = create_store_and_credential
        render json: create_store_and_credential
      end
    else
      @subscription.destroy
      render json: {
        valid: false,
        progress: @subscription.progress,
        errors: @subscription.get_progress_errors
      }
    end
  end

  def valid_tenant_name
    result = {}
    result['valid'] = true
    result['message'] = ''
    tenant_name = params[:tenant_name]
    if Tenant.where(name: tenant_name).empty?

      if (tenant_name =~ /^[0-9]*[A-Za-z][0-9A-Za-z]*$/).nil?
        result['valid'] = false
        result['message'] = 'Account name must include at least one letter'
      end

      if (tenant_name =~ /^[a-z0-9][a-z0-9_]*[a-z0-9]$/).nil?
        result['valid'] = false
        result['message'] = 'Site name can only contain lower case letters, numbers and underscores. They cannot start or end with an underscore'
      end
    else
      result['valid'] = false
      result['message'] = 'https://' + tenant_name + '.groovepacker.com already exists'
    end
    render json: result
  end

  def valid_email
    render json: { valid: Subscription.where(email: params[:email]).empty? }
  end

  def valid_username
    render json: { valid: Subscription.where(user_name: params[:user_name]).empty? }
  end

  def show
    flash[:notice] = params[:notice]
  end

  def complete; end

  def plan_info
    get_plan_info(params[:plan_id])
    render json: @result
  end

  def check_tenant_name
    Apartment::Tenant.current == '' ? true : (render status: 401)
  end

  def validate_coupon_id
    calculate_discount_amount(params[:coupon_id])
    render json: @result
  end

  def login; end

  def get_one_time_payment_fee
    result = {}
    result['one_time_payment'] = if params[:shop_name].present? && params['shop_type'] == 'BigCommerce'
                                   ENV['BC_ONE_TIME_PAYMENT']
                                 elsif params[:shop_name].present? && params['shop_type'] == 'Shopify'
                                   ENV['SHOPIFY_ONE_TIME_PAYMENT']
                                 else
                                   ENV['ONE_TIME_PAYMENT']
                                 end
    result['stripe_public_key'] = ENV['STRIPE_PUBLIC_KEY']
    render json: result
  end

  def create_payment_intent
    intent = Stripe::PaymentIntent.create(
      amount: params[:amount].to_i,
      currency: 'usd',
      metadata: { integration_check: 'accept_a_payment' }
    )

    render json: { client_secret: intent.client_secret, stripe_public_key: ENV['STRIPE_PUBLIC_KEY'] }.to_json
  end

  private

  def create_store_and_credential
    store = Store.create(
      name: params[:shop_name],
      store_type: params[:shop_type],
      status: '1',
      inventory_warehouse_id: get_default_warehouse_id
    )
    case params[:shop_type]
    when 'Shopify'
      response = create_shopify_credential(store.id)
    when 'BigCommerce'
      response = create_BigCommerce_credential(store.id)
    end
    response
  end

  def create_shopify_credential(store_id)
    token = $redis.get(params[:shop_name] + '.myshopify.com')
    shopify_credential = ShopifyCredential.create(shop_name: params[:shop_name], store_id: store_id, access_token: token)
    app_charge_id = $redis.get(params[:shop_name] + '.myshopify.com_otf')
    recurring_tenant_charge_id = $redis.get(params[:shop_name] + '.myshopify.com_rtc')
    @subscription.update(app_charge_id: app_charge_id, tenant_charge_id: recurring_tenant_charge_id, shopify_shop_name: params[:shop_name])
    $redis.del(params[:shop_name] + '.myshopify.com_ready_to_be_deployed')
    $redis.del(params[:shop_name] + '.myshopify.com_otf')
    $redis.del(params[:shop_name] + '.myshopify.com_rtc')
    { valid: true,
      transaction_id: @subscription.stripe_transaction_identifier,
      notice: 'Congratulations! Your GroovePacker is being deployed!',
      email: params[:email],
      next_date: (Time.current + 30.days).strftime('%B %d %Y'),
      store: 'Shopify' }
  end

  def create_BigCommerce_credential(store_id)
    access_token = begin
                     cookies[:store_access_token]
                   rescue StandardError
                     nil
                   end
    store_hash = begin
                   cookies[:store_context]
                 rescue StandardError
                   nil
                 end
    BigCommerceCredential.create(
      shop_name: params[:shop_name],
      store_id: store_id,
      access_token: access_token,
      store_hash: store_hash
    )
    # cookies.delete(:bc_auth)
    cookies[:store_access_token] = { value: nil, domain: :all, expires: Time.current + 2.seconds }
    cookies[:store_context] = { value: nil, domain: :all, expires: Time.current + 2.seconds }
    response = response_for_successful_subscription
    response['store'] = 'BigCommerce'
    response
  end

  def response_for_successful_subscription
    @result = get_next_payment_date(@subscription)
    { valid: true,
      transaction_id: @subscription.stripe_transaction_identifier,
      notice: 'Congratulations! Your GroovePacker is being deployed!',
      email: @subscription.email,
      next_date: @result['next_date'] }
  end

  def create_subscription(params)
    plan_price = begin
                   params[:plan_id].split('-').last.to_i
                 rescue StandardError
                   0
                 end
    params[:plan_id] = params[:plan_id].gsub('GROOV', params[:tenant_name])
    if params[:radio_subscription] == 'monthly'
      params[:amount] = plan_price * 100
      interval = 'month'
    else
      params[:amount] = (plan_price - (plan_price * 10 / 100)) * 12 * 100
      interval = 'year'
    end

    subscription = Subscription.new(stripe_user_token: params[:stripe_user_token],
                                    tenant_name: params[:tenant_name],
                                    amount: params[:amount],
                                    subscription_plan_id: params[:plan_id],
                                    email: params[:email],
                                    user_name: params[:user_name],
                                    password: params[:password],
                                    status: 'started',
                                    coupon_id: params[:coupon_id], interval: interval)
    if params['shop_name'].present? && (params['shop_type'] == 'Shopify')
      all_charges_paid = $redis.get("#{params['shop_name']}.myshopify.com_ready_to_be_deployed")
      subscription.shopify_customer = true
      subscription.all_charges_paid = all_charges_paid
    end
    subscription.save
    subscription
  end

  def split_position(plan_id)
    plan_id.length - plan_id.split('-').pop.length - 1
  end

  def fetch_plans_info
    [
      { 'name' => 'Duo',
        'plan_id' => 'groove-100',
        'amount' => '100',
        'users' => '2',
        'stores' => 'Unlimited',
        'shipments' => 'Unlimited' },
      { 'name' => 'Trio',
        'plan_id' => 'groove-150',
        'amount' => '150',
        'users' => '3',
        'stores' => 'Unlimited',
        'shipments' => 'Unlimited' },
      { 'name' => 'Quartet',
        'plan_id' => 'groove-200',
        'amount' => '200',
        'users' => '4',
        'stores' => 'Unlimited',
        'shipments' => 'Unlimited' },
      { 'name' => 'Quintet',
        'plan_id' => 'groove-250',
        'amount' => '250',
        'users' => '5',
        'stores' => 'Unlimited',
        'shipments' => 'Unlimited' },
      { 'name' => 'Big Band',
        'plan_id' => 'groove-350',
        'amount' => '350',
        'users' => '7',
        'stores' => 'Unlimited',
        'shipments' => 'Unlimited' },
      { 'name' => 'Symphony',
        'plan_id' => 'groove-500',
        'amount' => '500',
        'users' => '10',
        'stores' => 'Unlimited',
        'shipments' => 'Unlimited' }
    ]
  end
end
