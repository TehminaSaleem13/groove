# frozen_string_literal: true

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

  def list_activity_logs
    result = admin_activity_logs

    render json: result
  end

  def update_list_plan_restriction(type)
    current_tenant = Apartment::Tenant.current
    result = update_plan_ar(type)
    Apartment::Tenant.switch!(current_tenant)
    result['shopify_customer'] = begin
                                   Tenant.find(params['basicinfo']['id']).subscription.shopify_customer
                                 rescue StandardError
                                   nil
                                 end
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
    tenant = Tenant.find(params['id'])
    feature = params['feature']
    toggle =  params['value']['toggle']
    amount =  params['value']['amount']
    checked = params['value']['is_checked']
    db_price = begin
                  tenant.price.with_indifferent_access
               rescue StandardError
                 nil
                end
    unless db_price.blank?
      db_price[feature] ||= { stripe_id: '' }
      db_price[feature]['toggle'] = begin
                                      toggle
                                    rescue StandardError
                                      nil
                                    end
      db_price[feature]['amount'] = begin
                                      amount
                                    rescue StandardError
                                      nil
                                    end
    end
    tenant.price = db_price
    tenant.save
    add_plan_to_subscription(amount, tenant, feature, checked) if toggle == true
    remove_plan_to_subscription(tenant, feature) if toggle == false
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
    tenant = Tenant.find(params['tenant'])
    Apartment::Tenant.switch! tenant.name
    # setting = GeneralSetting.last
    # tenant.scheduled_import_toggle = params["scheduled_import_toggle"]
    # tenant.inventory_report_toggle = params["inventory_report_toggle"]
    tenant.test_tenant_toggle = params['test_tenant_toggle']
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
    tenant = Tenant.find(params['tenant_id'])
    tenant.scan_pack_workflow = params['workflow'] if params['workflow'].in? %w[default product_first_scan_to_put_wall scan_to_cart multi_put_wall]
    Apartment::Tenant.switch! tenant.name
    ToteSet.first || ToteSet.create(name: 'T')
    Apartment::Tenant.switch!
    tenant.save
    render json: {}
  end

  def update_store_order_respose_log
    tenant = Tenant.find(params['tenant_id'])
    tenant.store_order_respose_log = !tenant.store_order_respose_log
    tenant.save
    GroovS3.bucket.objects(prefix: "#{tenant.name}/se_import_log").each(&:destroy)
    render json: {}
  end

  def update_groovelytic_stat
    tenant = Tenant.find(params['tenant_id'])
    tenant.groovelytic_stat = !tenant.groovelytic_stat
    tenant.save
    unless tenant.groovelytic_stat
      Apartment::Tenant.switch! tenant.name
      users = User.where('username != ? and is_deleted = ?', 'gpadmin', false)
      users.update_all(view_dashboard: 'none')
    end
    render json: {}
  end

  def update_scheduled_import_toggle
    setting = GeneralSetting.last
    tenant = Tenant.find(params['tenant_id'])
    tenant.scheduled_import_toggle = !tenant.scheduled_import_toggle
    tenant.save
    if tenant.scheduled_import_toggle == false
      setting.schedule_import_mode = 'Daily'
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
    name = Tenant.find(params['tenant']).name
    Apartment::Tenant.switch! name
    OrderImportSummary.destroy_all
    ImportItem.destroy_all
    result[:status] = true
    render json: result
  end

  def activity_log
    AddLogCsv.new.delay(run_at: 1.seconds.from_now, queue: 'download_activity_log', priority: 95).send_activity_log
    render json: {}
  end

  def activity_log_v2
    AddLogCsv.new.delay(run_at: 1.seconds.from_now, queue: 'download_activity_log', priority: 95).send_activity_log_v2(params)
    render json: {}
  end

  def bulk_event_logs
    AddLogCsv.new.delay(run_at: 1.seconds.from_now, queue: 'download_bulk_event_logs', priority: 95).send_bulk_event_logs(params)
    render json: {}
  end

  def fix_product_data
    # FixProductData.new(params).delay(run_at: 1.seconds.from_now, queue: 'fix_products', priority: 95).call
    FixProductData.new(params).call
    render json: {}
  end

  def get_duplicates_order_info
    AddLogCsv.new.delay(run_at: 1.seconds.from_now, queue: 'download_duplicates_order_list', priority: 95).get_duplicates_order_info(params)
    render json: {}
  end

  def remove_duplicates_order
    OrderService::RemoveDuplicates.new.delay(run_at: 1.seconds.from_now, queue: 'remove_duplicates_order_list', priority: 95).get_duplicates_order_info(params)
    render json: {}
  end

  def tenant_log
    AddLogCsv.new.delay(run_at: 1.seconds.from_now, queue: 'download_tenant_log', priority: 95).send_tenant_log
    render json: {}
  end

  def clear_redis_method
    result = {}
    require 'rake'
    Groovepacks::Application.load_tasks
    Rake::Task['doo:clear_redis'].execute
    result[:status] = true
    render json: result
  end

  def clear_all_imports
    StopAllImportsJob.set(priority: 95).perform_later

    render json: { status: 'All import jobs will be stopped shortly' }
  end

  private

  def set_tenant_object
    @tenant = Tenant.find(params[:tenant_id])
  end

  def update_tenant_attributes(params)
    return false unless params[:setting]&.in?(Tenant.column_names)

    @tenant.update(params[:setting].to_sym => !@tenant.send(params[:setting]))
  end
end
