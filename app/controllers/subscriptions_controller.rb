class SubscriptionsController < ApplicationController
  include PaymentsHelper
  include StoresHelper
  # before_filter :check_tenant_name

  def new
    begin
      @subscription = Subscription.new
      plan_id = params[:plan_id]
      @monthly_amount = Stripe::Plan.retrieve(plan_id).amount
      position = split_position(plan_id)
      @annually_amount = Stripe::Plan.retrieve('an-' + plan_id[0..position - 1]).amount
    rescue Stripe::InvalidRequestError => e
      @plan_error = 'Please Select A Plan From The List'
      @plans = fetch_plans_info
      render :select_plan
    end
  end

  def select_plan
    @plan_error ||= ''
    @plans = fetch_plans_info
  end

  def confirm_payment
    @subscription = create_subscription(params)

    if @subscription
      one_time_payment = params[:shop_name].blank? ? ENV['ONE_TIME_PAYMENT'] : 0
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
        Apartment::Tenant.switch(@subscription.tenant_name)
        # response = create_store_and_credential
        render json: create_store_and_credential
      end
    else
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
    render json: { valid: Subscription.where(email: params[:email]).length == 0 }
  end

  def valid_username
    render json: { valid: Subscription.where(user_name: params[:user_name]).length == 0 }
  end

  def show
    flash[:notice] = params[:notice]
  end

  def complete
  end

  def plan_info
    get_plan_info(params[:plan_id])
    render json: @result
  end

  def check_tenant_name
    (Apartment::Tenant.current == '') ? true : (render status: 401)
  end

  def validate_coupon_id
    calculate_discount_amount(params[:coupon_id])
    render json: @result
  end

  def login
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
    return response
  end

  def create_shopify_credential(store_id)
    shopify_credential = ShopifyCredential.create(shop_name: params[:shop_name], store_id: store_id)
    return{ valid: true,
            redirect_url:
              Groovepacker::ShopifyRuby::Utilities.new(
                shopify_credential
              ).permission_url(params[:tenant_name], true)
          }
  end

  def create_BigCommerce_credential(store_id)
    access_token = cookies[:store_access_token] rescue nil
    store_hash = cookies[:store_context] rescue nil
    BigCommerceCredential.create(
      shop_name: params[:shop_name],
      store_id: store_id,
      access_token: access_token,
      store_hash: store_hash
    )
    # cookies.delete(:bc_auth)
    cookies[:store_access_token] = { :value => nil, :domain => :all, :expires => Time.now + 2.seconds }
    cookies[:store_context] = { :value => nil, :domain => :all, :expires => Time.now + 2.seconds }
    return response_for_successful_subscription
  end

  def response_for_successful_subscription
    @result = get_next_payment_date(@subscription)
    return{ valid: true,
            transaction_id: @subscription.stripe_transaction_identifier,
            notice: 'Congratulations! Your GroovePacker is being deployed!',
            email: @subscription.email,
            next_date: @result['next_date']
          }
  end

  def create_subscription(params)
    Subscription.create(stripe_user_token: params[:stripe_user_token],
                        tenant_name: params[:tenant_name],
                        amount: params[:amount],
                        subscription_plan_id: params[:plan_id],
                        email: params[:email],
                        user_name: params[:user_name],
                        password: params[:password],
                        status: 'started',
                        coupon_id: params[:coupon_id])
  end

  def split_position(plan_id)
    plan_id.length - plan_id.split('-').pop.length - 1
  end

  def fetch_plans_info
    [
      { 'name' => 'Duo',
        'plan_id' => 'groove-duo-60',
        'amount' => '60',
        'users' => '2',
        'stores' => '2',
        'shipments' => '2,200'
      },
      { 'name' => 'Trio',
        'plan_id' => 'groove-trio-90',
        'amount' => '90',
        'users' => '3',
        'stores' => '3',
        'shipments' => '4,500'
      },
      { 'name' => 'Quartet',
        'plan_id' => 'groove-quartet-120',
        'amount' => '120',
        'users' => '4',
        'stores' => '4',
        'shipments' => '6,700'
      },
      { 'name' => 'Quintet',
        'plan_id' => 'groove-quintet-150',
        'amount' => '150',
        'users' => '5',
        'stores' => '5',
        'shipments' => '9,000'
      },
      { 'name' => 'Big Band',
        'plan_id' => 'groove-bigband-210',
        'amount' => '210',
        'users' => '7',
        'stores' => '7',
        'shipments' => '14,000'
      },
      { 'name' => 'Symphony',
        'plan_id' => 'groove-symphony-300',
        'amount' => '300',
        'users' => '10',
        'stores' => 'Unlimited',
        'shipments' => '20,000'
      }
    ]
  end
end
