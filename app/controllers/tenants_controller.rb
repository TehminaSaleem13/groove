class TenantsController < ApplicationController
  include PaymentsHelper
  include TenantsHelper

  before_action :set_tenant_object, only: :update_setting
  before_action :groovepacker_authorize!

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
    current_tenant = Apartment::Tenant.current
    result = update_plan_ar(type)
    Apartment::Tenant.switch!(current_tenant)
    result["shopify_customer"] = Tenant.find(params["basicinfo"]["id"]).subscription.shopify_customer rescue nil
    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: result }
    end
  end

  def destroy
    current_tenant = Apartment::Tenant.current
    result = delete_data_single
    Apartment::Tenant.switch!(current_tenant)

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
    db_price =  tenant.price rescue nil
    unless db_price.blank?
      db_price[feature]["toggle"] = toggle rescue nil
      db_price[feature]["amount"] = amount rescue nil
    end
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
    Apartment::Tenant.switch! tenant.name
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

  def update_setting
    render json: { status: update_tenant_attributes(params) }
  end

  def update_scan_workflow
    tenant = Tenant.find(params["tenant_id"])
    tenant.scan_pack_workflow = params['workflow'] if params['workflow'].in? %w(default product_first_scan_to_put_wall)
    Apartment::Tenant.switch! tenant.name
    ToteSet.last || ToteSet.create(name: 'T')
    Apartment::Tenant.switch!
    tenant.save
    render json: {}
  end

  def update_store_order_respose_log
    tenant = Tenant.find(params["tenant_id"])
    tenant.store_order_respose_log = !tenant.store_order_respose_log
    tenant.save
    GroovS3.bucket.objects({prefix: "#{tenant.name}/se_import_log"}).each { |obj| obj.destroy }
    render json: {}
  end

  def update_groovelytic_stat
    tenant = Tenant.find(params["tenant_id"])
    tenant.groovelytic_stat = !tenant.groovelytic_stat
    tenant.save
    unless tenant.groovelytic_stat
      Apartment::Tenant.switch! tenant.name
      users = User.where('username != ? and is_deleted = ?', 'gpadmin', false)
      users.update_all(view_dashboard: "none")
    end
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
    Apartment::Tenant.switch! name
    OrderImportSummary.update_all(status: "cancelled")
    ImportItem.update_all(status: "cancelled")
    result[:status] = true
    render json: result
  end

  def activity_log
    AddLogCsv.new.delay(:run_at => 1.seconds.from_now, :queue => "download_activity_log", priority: 95).send_activity_log
    render json: {}
  end

  def activity_log_v2
    AddLogCsv.new.delay(:run_at => 1.seconds.from_now, :queue => "download_activity_log", priority: 95).send_activity_log_v2(params)
    render json: {}
  end

  def get_duplicates_order_info
    AddLogCsv.new.delay(:run_at => 1.seconds.from_now, :queue => "download_duplicates_order_list", priority: 95).get_duplicates_order_info(params)
    render json: {}
  end

  def remove_duplicates_order
    OrderService::RemoveDuplicates.new.delay(:run_at => 1.seconds.from_now, :queue => "remove_duplicates_order_list", priority: 95).get_duplicates_order_info(params)
    render json: {}
  end

  def tenant_log
    AddLogCsv.new.delay(:run_at => 1.seconds.from_now, :queue => "download_tenant_log", priority: 95).send_tenant_log
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
      Apartment::Tenant.switch!(tenant.name)
      ImportItem.where("status='in_progress' OR status='not_started'").update_all(status: 'cancelled')
      items = ImportItem.joins(:store).where("stores.store_type='CSV' and (import_items.status='in_progress' OR import_items.status='not_started' OR import_items.status='failed')")
      items.each {|item| item.update_attributes(status: 'cancelled')} rescue nil
      order_import_summary = OrderImportSummary.all
      order_import_summary.each do |import_summary|
        import_summary.status = "completed"
        import_summary.save
      end
    end

    render json: { status: 'Cleared all import jobs' }
  end

  private

  def set_tenant_object
    @tenant = Tenant.find(params[:tenant_id])
  end

  def update_tenant_attributes(params)
    return false unless params[:setting] && params[:setting].in?(Tenant.column_names)

    @tenant.update(params[:setting].to_sym => !@tenant.send(params[:setting]))
  end
end
