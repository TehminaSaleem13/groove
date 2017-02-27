module TenantsHelper
  include ApplicationHelper

  def admin_list_info
    result = result_hash
    @search = params[:search]
    tenants = []
    helper = Groovepacker::Tenants::Helper.new
    if @search && @search != ''
      search_result = helper.do_search(params)
      tenants = search_result['tenants']
      result['tenants_count'] = {}
      result['tenants_count']['search'] = search_result['count']
    else
      tenants = helper.do_gettenants(params)
    end
    get_tenants_info(helper, tenants, params, result)
    result
  end

  def admin_single_info
    result = result_hash
    if params[:id]
      @tenant = find_tenant(params[:id])
      if @tenant
        @tenant.reload
        build_tenant_hash(result, @tenant)
      end
    end
    result
  end

  def admin_single_update
    result = result_hash
    @tenant = find_tenant(params[:id])
    if @tenant
      helper = Groovepacker::Tenants::Helper.new
      result = helper.update_tenant(@tenant, params)
    else
      update_fail_status(result, 'Could not find tenant')
    end
    result
  end

  def update_plan_ar(type)
    result = result_hash
    @tenant = find_tenant(params[:id])
    if @tenant
      @tenant.update_attribute(:orders_delete_days, params["basicinfo"]["orders_delete_days"]) if params["basicinfo"].present?
      helper = Groovepacker::Tenants::Helper.new
      case type
      when 'update_restriction'
        subsc = @tenant.subscription
        if subsc.shopify_customer
          access = params["access_restrictions_info"]
          subsc.tenant_data = "#{params["subscription_info"]["amount"]}-#{access['max_allowed']}-#{access['max_users']}-#{access['max_import_sources']}"
          subsc.shopify_payment_token = SecureRandom.hex #(0...20).map { ('a'..'z').to_a[rand(15)] }.join
          subsc.save
          ShopifyMailer.recurring_payment(@tenant, "http://#{@tenant.name}.localpacker.com/shopify/update_customer_plan.json?one_time_token=#{subsc.shopify_payment_token}").deliver
        else
          result = helper.update_restrictions(@tenant, params)
        end
        result = helper.update_tenant(@tenant, params) if result['status'] == true
        result = helper.update_subscription_plan(@tenant, params) if result['status'] == true
      when 'update_node'
        result = helper.update_node(@tenant, params)
      when 'update_zero_subscription'
        subsc = @tenant.subscription
        new_plan = "#{@tenant.name}-zero-plan"
        if !subsc.subscription_plan_id.include?("-zero-plan")
          Stripe::Plan.create(amount: 0, interval: "month", name: new_plan.gsub("-", " ").capitalize, currency: "usd", id: new_plan, trial_period_days: 0) rescue nil
          stripe_subsc = Stripe::Customer.retrieve(subsc.stripe_customer_id).subscriptions
          stripe_subsc["data"][0].delete if stripe_subsc.data.present?
          new_subsc = stripe_subsc.create(:plan => new_plan)
          subsc.interval = "month"
          subsc.customer_subscription_id =  new_subsc.id
          subsc.subscription_plan_id = new_plan
          subsc.save
        end
      end
    else
      result['status'] = false
    end
    result
  end

  def delete_data_single
    result = result_hash
    @tenant = find_tenant(params[:id])
    if @tenant
      if check_permission(params[:action_type])
        helper = Groovepacker::Tenants::Helper.new
        result = helper.delete_data(@tenant, params, result, current_user)
      else
        update_fail_status(result, "You don't have enough permission to delete tenant data")
      end
    else
      result['status'] = false
    end
    result
  end

  def delete_tenants
    result = result_hash
    tenants = list_selected_tenants
    if tenants
      tenants.each do |tenant|
        helper = Groovepacker::Tenants::Helper.new
        result = helper.delete(tenant)
      end
    else
      update_fail_status(result, 'Selected list is empty')
    end
    result
  end

  def create_single_duplicate
    result = result_hash
    id = params[:id]
    @tenant = find_tenant(id)
    if @tenant
      helper = Groovepacker::Tenants::Helper.new
      result = helper.duplicate(id, params[:name])
    else
      update_fail_status(result, "The tenant doesn't exist")
    end
    result
  end

  def get_tenants_info(helper, tenants, params, result)
    result['tenants'] = helper.make_tenants_list(tenants, params)
    result['tenants_count'] = get_tenants_count
  end

  def get_tenants_count
    count = {}
    counts = Tenant.select('count(*) as count')
    all = 0
    counts.each do |single|
      # count[single.status] = single.count
      all += single.count
    end
    count['all'] = all
    count['search'] = 0
    count
  end

  def build_tenant_hash(result, tenant)
    result['tenant'] = {}
    result['tenant']['basicinfo'] = tenant.attributes
    helper = Groovepacker::Tenants::Helper.new
    result['tenant']['subscription_info'] = helper.get_subscription_data(tenant.name, "show")
    access_info = Groovepacker::Dashboard::Stats::ShipmentStats.new
    result['tenant']['access_restrictions_info'] = access_info.get_shipment_stats(tenant.name)
  end

  def list_selected_tenants
    tenants_list = params['_json']
    tenants = []
    tenants_list.each do |tenant|
      tenants.push(tenant['name'])
    end
    tenants
  end

  def check_permission(action_type)
    if action_type == 'orders'
      return current_user.can?('delete_orders')
    elsif action_type == 'products'
      return current_user.can?('delete_products')
    elsif action_type == 'both'
      return current_user.can?('delete_products') && current_user.can?('delete_orders')
    elsif action_type == 'all'
      return true
    end
    return false
  end
end