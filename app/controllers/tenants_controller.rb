class TenantsController < ApplicationController
  include PaymentsHelper
  include TenantsHelper

  def index
    result = admin_list_info
    # @search = params[:search]
    # tenants = []
    # helper = Groovepacker::Tenants::Helper.new
    # if @search && @search != ''
    #   search_result = helper.do_search(params)
    #   tenants = search_result['tenants']
    #   result['tenants_count'] = {}
    #   result['tenants_count']['search'] = tenants['count']
    # else
    #   tenants = helper.do_gettenants(params)
    # end
    # get_tenants_info(helper, tenants, params, result)

    respond_to do |format|
      format.json { render json: result }
    end
  end

  def show
    result = admin_single_info
    # if params[:id]
    #   @tenant = find_tenant(params[:id])
    #   if @tenant
    #     @tenant.reload
    #     build_tenant_hash(result, @tenant)
    #   end
    # end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: result }
    end
  end

  def update
    result = admin_single_update

    # @tenant = find_tenant(params[:id])
    # if @tenant
    #   helper = Groovepacker::Tenants::Helper.new
    #   result = helper.update_tenant(@tenant, params)
    # else
    #   update_fail_status(result, 'Could not find tenant')
    # end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: result }
    end
  end

  def update_access_restrictions
    update_list_plan_restriction('update_restriction')
  end

  def update_tenant_list
    update_list_plan_restriction('update_node')
  end

  def update_list_plan_restriction(type)
    # result = result_hash
    current_tenant = Apartment::Tenant.current_tenant
    result = update_plan_ar(type)
    # @tenant = find_tenant(params[:id])
    # if @tenant
    #   helper = Groovepacker::Tenants::Helper.new
    #   case type
    #   when 'update_restriction'
    #     result = helper.update_restrictions(@tenant, params)
    #     result = helper.update_tenant(@tenant, params) if result['status'] == true
    #     result = helper.update_subscription_plan(@tenant, params) if result['status'] == true
    #   when 'update_node'
    #     result = helper.update_node(@tenant, params)
    #   end
    # else
    #   result['status'] = false
    # end
    Apartment::Tenant.switch(current_tenant)

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: result }
    end
  end

  def destroy
    # result = result_hash
    current_tenant = Apartment::Tenant.current_tenant
    result = delete_data_single
    # @tenant = find_tenant(params[:id])
    # if @tenant
    #   if check_permission(params[:action_type])
    #     helper = Groovepacker::Tenants::Helper.new
    #     result = helper.delete_data(params, current_user)
    #   else
    #     update_fail_status(result, "You don't have enough permission to delete tenant data")
    #   end
    # else
    #   result['status'] = false
    # end
    Apartment::Tenant.switch(current_tenant)

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: result }
    end
  end

  def delete_tenant
    result = delete_tenants

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: result }
    end
  end

  def create_duplicate
    result = create_single_duplicate

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: result }
    end
  end
end
