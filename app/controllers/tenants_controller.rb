class TenantsController < ApplicationController
  include PaymentsHelper
  include TenantsHelper

  before_filter :groovepacker_authorize!

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

  def update_zero_subscription
    update_list_plan_restriction('update_zero_subscription')
  end

  def update_list_plan_restriction(type)
    current_tenant = Apartment::Tenant.current_tenant
    result = update_plan_ar(type)
    Apartment::Tenant.switch(current_tenant)
    result["shopify_customer"] = Tenant.find(params["basicinfo"]["id"]).subscription.shopify_customer rescue nil
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

  def update_price_field
    tenant = Tenant.find(params["id"])
    feature = params["feature"]
    toggle =  params["value"]["toggle"]
    amount =  params["value"]["amount"]
    db_price =  tenant.price
    db_price[feature]["toggle"] = toggle
    db_price[feature]["amount"] = amount
    tenant.price = db_price
    tenant.save
    add_plan_to_subscription(amount, tenant, feature) if toggle == true
    remove_plan_to_subscription(tenant, feature)  if  toggle == false
    render json: {}
  end

  def delete_tenant
    result = delete_tenants

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: result }
    end
  end

  def update_import_mode
    tenant = Tenant.find(params["tenant"])
    Apartment::Tenant.switch tenant.name
    # setting = GeneralSetting.last
    #tenant.scheduled_import_toggle = params["scheduled_import_toggle"]
    #tenant.inventory_report_toggle = params["inventory_report_toggle"]
    tenant.test_tenant_toggle = params["test_tenant_toggle"]
    tenant.save
    # if tenant.scheduled_import_toggle == false
    #   setting.schedule_import_mode = "Daily"
    #   setting.save
    # end
    render json: {}
  end

  def update_fba
    tenant = Tenant.find(params["tenant_id"])
    tenant.is_fba = !tenant.is_fba
    tenant.save
    render json: {}
  end

  def update_api_call
    tenant = Tenant.find(params["tenant_id"])
    tenant.api_call = !tenant.api_call
    tenant.save
    render json: {}
  end

  def update_allow_rts
    tenant = Tenant.find(params["tenant_id"])
    tenant.allow_rts = !tenant.allow_rts
    tenant.save
    render json: {}
  end

  def update_product_ftp_import
    tenant = Tenant.find(params["tenant_id"])
    tenant.product_ftp_import = !tenant.product_ftp_import
    tenant.save
    render json: {}
  end

  def update_product_activity_switch
    tenant = Tenant.find(params["tenant_id"])
    tenant.product_activity_switch = !tenant.product_activity_switch
    tenant.save
    render json: {}
  end

  def update_scan_workflow
    tenant = Tenant.find(params["tenant_id"])
    tenant.scan_pack_workflow = params['workflow'] if params['workflow'].in? %w(default product_first_scan_to_put_wall)
    Apartment::Tenant.switch tenant.name
    ToteSet.last || ToteSet.create(name: 'T')
    Apartment::Tenant.switch
    tenant.save
    render json: {}
  end

  def update_groovelytic_stat
    tenant = Tenant.find(params["tenant_id"])
    tenant.groovelytic_stat = !tenant.groovelytic_stat
    tenant.save
    unless tenant.groovelytic_stat
      Apartment::Tenant.switch tenant.name
      users = User.where('username != ? and is_deleted = ?', 'gpadmin', false)
      users.update_all(view_dashboard: "none")
    end
    render json: {}
  end

  def update_is_delay
    tenant = Tenant.find(params["tenant_id"])
    tenant.is_delay = !tenant.is_delay
    tenant.save
    render json: {}
  end

  def update_scheduled_import_toggle
    setting = GeneralSetting.last
    tenant = Tenant.find(params["tenant_id"])
    tenant.scheduled_import_toggle = !tenant.scheduled_import_toggle
    tenant.save
    if tenant.scheduled_import_toggle == false
      setting.schedule_import_mode = "Daily"
      setting.save
    end
    render json: {}
  end


  def update_inventory_report_toggle
    tenant = Tenant.find(params["tenant_id"])
    tenant.inventory_report_toggle = !tenant.inventory_report_toggle
    tenant.save
    render json: {}
  end

  def update_custom_fields
    tenant = Tenant.find(params["tenant_id"])
    tenant.custom_product_fields = !tenant.custom_product_fields
    tenant.save
    render json: {}
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

  def activity_log
    AddLogCsv.new.delay(:run_at => 1.seconds.from_now, :queue => "download_activity_log").send_activity_log
    render json: {}
  end

  def tenant_log
    AddLogCsv.new.delay(:run_at => 1.seconds.from_now, :queue => "download_tenant_log").send_tenant_log
    render json: {}
  end

  def clear_redis_method
    result = {}
    require 'rake'
    Groovepacks::Application.load_tasks
    Rake::Task['doo:clear_redis'].execute
    result[:status] =  true
    render json: result
  end

  def clear_all_imports
    Tenant.find_each do |tenant|
      Apartment::Tenant.switch(tenant.name)
      ImportItem.where("status='in_progress' OR status='not_started'").update_all(status: 'cancelled')
      items = ImportItem.includes(:store).where("stores.store_type='CSV' and (import_items.status='in_progress' OR import_items.status='not_started' OR import_items.status='failed')")
      items.each {|item| item.update_attributes(status: 'cancelled')} rescue nil
      order_import_summary = OrderImportSummary.all
      order_import_summary.each do |import_summary|
        import_summary.status = "completed"
        import_summary.save
      end
    end

    render json: { status: 'Cleared all import jobs' }
  end
end
