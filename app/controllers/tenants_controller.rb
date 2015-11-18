class TenantsController < ApplicationController
  include PaymentsHelper

  def index
    result = {}
    result[:status] = true
    helper = Groovepacker::Tenants::Helper.new
    if !params[:search].nil? && params[:search] != ''
      tenants = helper.do_search(params)
      result['tenants'] = helper.make_tenants_list(tenants['tenants'], params)
      result['tenants_count'] = get_tenants_count
      result['tenants_count']['search'] = tenants['count']
    else
      tenants = helper.do_gettenants(params)
      result['tenants'] = helper.make_tenants_list(tenants, params)
      result['tenants_count'] = get_tenants_count()
    end

    respond_to do |format|
      format.json { render json: result }
    end
  end

  def show
    result = {}
    tenant = nil
    if !params[:id].nil?
      tenant = Tenant.find_by_id(params[:id])
    end
    if !tenant.nil?
      tenant.reload
      general_setting = GeneralSetting.all.first
      scan_pack_setting = ScanPackSetting.all.first

      result['tenant'] = Hash.new
      result['tenant']['basicinfo'] = tenant.attributes
      helper = Groovepacker::Tenants::Helper.new
      result['tenant']['subscription_info'] = helper.get_subscription_data(tenant.name)
      access_info = Groovepacker::Dashboard::Stats::ShipmentStats.new
      result['tenant']['access_restrictions_info'] = access_info.get_shipment_stats(tenant.name)
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: result }
    end
  end

  def update
    result = {}
    result['status'] = true
    result['error_messages'] = []

    tenant = Tenant.find(params[:id])
    unless tenant.nil?
      helper = Groovepacker::Tenants::Helper.new
      helper.update_tenant(tenant, params, result)
    else
      result['status'] = false
      result['error_messages'].push('Could not find tenant')
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: result }
    end
  end

  def update_access_restrictions
    result = {}
    result['status'] = true
    result['error_messages'] = []
    tenant = nil
    current_tenant = Apartment::Tenant.current_tenant
    tenant = Tenant.find(params[:id])

    unless tenant.nil?
      helper = Groovepacker::Tenants::Helper.new
      helper.update_restrictions(tenant, params, result)
    else
      result['status'] = false
    end
    Apartment::Tenant.switch(current_tenant)

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: result }
    end
  end

  def destroy
    result = {}
    result['status'] = true
    result['error_messages'] = []
    tenant = nil
    current_tenant = Apartment::Tenant.current_tenant
    tenant = Tenant.find(params[:id])
    unless tenant.nil?
      if check_permission(params[:action_type])
        helper = Groovepacker::Tenants::Helper.new
        helper.delete_data(tenant, params, result, current_user)
      else
        result['status'] = false
        result['error_messages'].push("You don't have enough permission to delete tenant data")
      end
    else
      result['status'] = false
    end
    Apartment::Tenant.switch(current_tenant)

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: result }
    end
  end

  def delete_tenant
    result = {}
    result['status'] = true
    result['error_messages'] = []
    result['success_messages'] = []
    tenants = list_selected_tenants
    unless tenants.nil?
      tenants.each do |tenant|
        helper = Groovepacker::Tenants::Helper.new
        helper.delete(tenant, result)
      end
    else
      result['status'] = false
      result['error_messages'].push("Selected list is empty")
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: result }
    end
  end

  def create_duplicate
    
    result = {}
    result['status'] = true
    result['error_messages'] = []
    result['success_messages'] = []
    tenant = Tenant.find(params[:id])
    unless tenant.nil?
      helper = Groovepacker::Tenants::Helper.new
      helper.duplicate(tenant, result, params[:name])
    else
      result['status'] = false
      result['error_messages'].push("The tenant doesn't exist")
    end
    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: result }
    end
  end

  def update_tenant_list
    result = {}
    result['status'] = true
    result['error_messages'] = []
    result['success_messages'] = []

    current_tenant = Apartment::Tenant.current_tenant
    tenant = Tenant.find(params[:id])
    unless tenant.nil?
      helper = Groovepacker::Tenants::Helper.new
      helper.update_node(tenant, params, result)
    else
      result['status'] = false
    end
    Apartment::Tenant.switch(current_tenant)

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: result }
    end
  end

  private

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
