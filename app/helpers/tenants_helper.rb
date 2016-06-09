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
      helper = Groovepacker::Tenants::Helper.new
      case type
      when 'update_restriction'
        result = helper.update_restrictions(@tenant, params)
        result = helper.update_tenant(@tenant, params) if result['status'] == true
        result = helper.update_subscription_plan(@tenant, params) if result['status'] == true
      when 'update_node'
        result = helper.update_node(@tenant, params)
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
    result['tenant']['subscription_info'] = helper.get_subscription_data(tenant.name)
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