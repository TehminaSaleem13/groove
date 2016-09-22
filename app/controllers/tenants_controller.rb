class TenantsController < ApplicationController
  include PaymentsHelper
  include TenantsHelper

  def index
    result = admin_list_info

    respond_to do |format|
      format.json { render json: result }
    end
  end

  def show
    result = admin_single_info
    result['tenant']['logged_in_user'] = current_user.name
    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: result }
    end
  end

  def update
    result = admin_single_update

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
    current_tenant = Apartment::Tenant.current_tenant
    result = update_plan_ar(type)
    Apartment::Tenant.switch(current_tenant)

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: result }
    end
  end

  def destroy
    current_tenant = Apartment::Tenant.current_tenant
    result = delete_data_single
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

  def delete_summary
    result = {}
    name = Tenant.find(params["tenant"]).name
    Apartment::Tenant.switch name
    OrderImportSummary.where("status = ? or status = ? ", "not_started", "in_progress").update_all(status: "cancelled")
    ImportItem.where("status = ? or status = ? ", "not_started", "in_progress").update_all(status: "cancelled")
    result[:status] = true
    render json: result
  end
end
