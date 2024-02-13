# frozen_string_literal: true

class ImportOrders < Groovepacker::Utilities::Base
  include Connection
  include AhoyEvent

  def import_orders(tenant)
    Apartment::Tenant.switch!(tenant)
    Time.use_zone(GeneralSetting.new_time_zone) do
      # we will remove all the jobs pertaining to import which are not started
      # we will also remove all the import summary which are not started.
      @order_import_summary = get_order_import_summary
      return if @order_import_summary.nil?

      # add import item for each store
      stores = Store.where("status = '1' AND store_type != 'system' AND store_type != 'Shipworks'")
      stores.each { |store| add_import_item_for_active_stores(store) } unless stores.blank?
      order_import_summaries.where("status!='in_progress' and id!=?", @order_import_summary.id).destroy_all
      initiate_import(tenant)
      last_status = GrooveBulkActions.last.try(:status)
      Groovepacker::Orders::BulkActions.new.delay(priority: 95).update_bulk_orders_status(nil, nil, Apartment::Tenant.current) if last_status == 'in_progress' || last_status == 'pending'
    end
  end

  def add_import_item_for_active_stores(store)
    imp_items = ImportItem.where('store_id = ? AND order_import_summary_id IS NOT NULL', store.id)
    unless store.store_type == 'CSV' && store.ftp_credential && store.ftp_credential.use_ftp_import == false
      last_completed = imp_items.last.try(:updated_at)
      $redis.set("#{Apartment::Tenant.current}_#{store.id}", last_completed)
      imp_items.delete_all
      ImportItem.where("store_id = ? AND status !='completed'", store.id).update_all(status: 'cancelled')
      new_import_item(store.id, nil, 'not_started')
      return
    end
    if imp_items.empty?
      new_import_item(store.id, 'CSV Importers Ready. FTP Order Import Is Off')
    elsif imp_items.where("status = 'failed'").present?
      last_completed = imp_items.last.try(:updated_at)
      $redis.set("#{Apartment::Tenant.current}_#{store.id}", last_completed)
      imp_items.delete_all
      new_import_item(store.id, 'FTP Order Import Is Off')
    end
  end

  def initiate_import(tenant)
    # delete existing completed and cancelled order import summaries
    track_user(tenant, { store_id: nil, user_id: import_params[:user_id] }, 'Import Started', 'Order Import Started')
    delete_existing_order_import_summaries
    return if @order_import_summary.nil? || @order_import_summary.id.nil?

    track_changes(title: 'Import Started : Order Import Summary ' + @order_import_summary.id.to_s, tenant: tenant,
                  username: (begin
                   User.find(@order_import_summary.user_id).username
                             rescue StandardError
                               nil
                 end) || 'GP App', object_id: @order_import_summary.id)
    @order_import_summary.import_items.reload.find_each(batch_size: 100) do |import_item|
      next if import_item.status == 'cancelled'

      import_orders_with_import_item(import_item, tenant)
    end
    update_import_summary if OrderImportSummary.find_by_id(@order_import_summary.id).present?
  end

  def update_import_summary
    @order_import_summary.reload
    return if @order_import_summary.status == 'cancelled'

    @order_import_summary.update_attributes(status: 'completed')
  end

  # params should have hash of tenant, store, import_type = 'regular', user
  def import_order_by_store(params, result = {})
    Apartment::Tenant.switch!(params[:tenant])
    Time.use_zone(GeneralSetting.new_time_zone) do
      if OrderImportSummary.where(status: 'in_progress').empty?
        run_import_for_single_store(params)
      else
        # import is already running. back off from importing
        result.merge(status: false, messages: 'An import is already running.')
      end
    end
    result
  end

  def import_range_import(params)
    Apartment::Tenant.switch! params[:tenant]
    Time.use_zone(GeneralSetting.new_time_zone) do
      import_item = ImportItem.create(store_id: params[:store_id], import_type: params[:import_type])
      store = Store.find(params[:store_id])
      handler = Groovepacker::Utilities::Base.new.get_handler(store.store_type, store, import_item)
      context = Groovepacker::Stores::Context.new(handler)
      if params[:import_type] == 'range_import'
        context.range_import(params[:start_date], params[:end_date], params[:order_date_type], params[:current_user_id])
      else
        fetched_order = Order.find_by_increment_id(params[:order_id])
        context.quick_fix_import(params[:import_date], fetched_order.id, params[:current_user_id]) if fetched_order.present?
      end
    end
  end

  def import_missing_order(params)
    Apartment::Tenant.switch! params[:tenant]
    Time.use_zone(GeneralSetting.new_time_zone) do
      store = Store.find(params[:store_id])
      import_item = ImportItem.create(store_id: store.id, status: 'on_demand')
      handler = Groovepacker::Utilities::Base.new.get_handler(store.store_type, store, import_item)
      context = Groovepacker::Stores::Context.new(handler)
      if store.store_type.in? %w[ShippingEasy Shopify Shippo]
        context.import_single_order_from(params[:order_no])
      else
        context.import_single_order_from_ss_rest(params[:order_no], params[:current_user], nil, params[:controller])
      end
    end
  end

  def run_import_for_single_store(params)
    Apartment::Tenant.switch!(params[:tenant])
    Time.use_zone(GeneralSetting.new_time_zone) do
      # delete existing completed and cancelled order import summaries
      delete_existing_order_import_summaries
      # add a new import summary
      import_summary = OrderImportSummary.create(user: params[:user], status: 'not_started')
      # add import item for the store
      ImportItem.where(store_id: params[:store].id).update_all(status: 'cancelled')
      ImportItem.where(store_id: params[:store].id).destroy_all
      import_summary.import_items.create(status: 'not_started', store: params[:store], import_type: params[:import_type], days: params[:days])
      # start importing using delayed job (ImportJob is defined in base class)
      track_user(params[:tenant], params, 'Import Started', 'Order Import Started')
      # Delayed::Job.enqueue ImportJob.new(params[:tenant], import_summary.id), :queue => 'importing_orders_'+ params[:tenant], priority: 95
      Groovepacker::Utilities::Base.new.delay(queue: "importing_orders_#{Apartment::Tenant.current}", priority: 95).order_import_job(params[:tenant], import_summary.id)
    end
  end

  def reschedule_job(type, tenant)
    Apartment::Tenant.switch!(tenant)
    Time.use_zone(GeneralSetting.new_time_zone) do
      date = DateTime.now.in_time_zone + 1.day
      job_scheduled = false
      general_settings = GeneralSetting.all.first
      export_settings = ExportSetting.all.first
      schedule_a_job(type, date, job_scheduled, general_settings, export_settings)
    end
  end

  def schedule_a_job(type, date, job_scheduled, general_settings, export_settings)
    should_schedule_job = false
    case type
    when 'import_orders'
      should_schedule_job, time = schedule_import_orders(general_settings, date)
    when 'low_inventory_email'
      should_schedule_job, time = schedule_low_inventory_email(general_settings, date, should_schedule_job)
    when 'inv_report'
      should_schedule_job, time = schedule_inventory_report(general_settings, date, should_schedule_job)
    when 'export_order'
      should_schedule_job, time = schedule_export_order(export_settings, date, should_schedule_job)
    end
    job_scheduled, date = get_scheduled_job(should_schedule_job, general_settings, job_scheduled, date, time, type)

    [job_scheduled, date]
  end

  def get_scheduled_job(should_schedule_job, general_settings, job_scheduled, date, time, type)
    if should_schedule_job
      job_scheduled = general_settings.schedule_job(date, time, type)
    else
      date += 1.day
    end
    [job_scheduled, date]
  end

  def schedule_import_orders(general_settings, date)
    should_schedule_job = general_settings.should_import_orders(date)
    time = general_settings.time_to_import_orders
    [should_schedule_job, time]
  end

  def schedule_low_inventory_email(general_settings, date, should_schedule_job, time = nil)
    if general_settings.low_inventory_alert_email? && general_settings.low_inventory_email_address.present?
      should_schedule_job = general_settings.should_send_email(date)
      time = general_settings.time_to_send_email
    end
    [should_schedule_job, time]
  end

  def schedule_inventory_report(_general_settings, date, should_schedule_job, time = nil)
    scheduled_reports = ProductInventoryReport.where(scheduled: true)
    inventory_report_settings = InventoryReportsSetting.last

    return [should_schedule_job, time] if scheduled_reports.blank? || !inventory_report_settings.report_email.present?

    should_schedule_job = inventory_report_settings.should_send_email(date)
    time = inventory_report_settings.time_to_send_report_email

    [should_schedule_job, time]
  end

  def schedule_export_order(export_settings, date, should_schedule_job, time = nil)
    unless export_settings.auto_email_export? && export_settings.order_export_email.present?
      return should_schedule_job, time
    end

    should_schedule_job = export_settings.should_export_orders(date)
    time = export_settings.time_to_send_export_email
    [should_schedule_job, time]
  end

  def import_orders_with_import_item(import_item, tenant)
    store_type = import_item.store.store_type
    store = import_item.store
    if store_type == 'CSV'
      initiate_csv_import(tenant, store_type, store, import_item) if import_item.status.present?
    else
      handler = get_handler(store_type, store, import_item)
      connection_successful = check_connection_for_shopify_or_bc_or_shippo(store, store_type, import_item)
      return unless connection_successful

      initiate_import_for(store, import_item, handler)
    end
  rescue Exception => e
    update_import_item_and_send_mail(e, import_item, tenant)
  end

  def initiate_csv_import(tenant, _store_type, store, import_item)
    mapping = CsvMapping.find_by_store_id(store.id)
    return unless check_connection_for_csv_import(mapping, store, import_item)

    if store.csv_beta
      import_item.order_import_summary.update_attributes(status: 'not_started', display_summary: false)
    else
      import_item.update_attributes(status: 'in_progress')
    end
    map = mapping.order_csv_map
    map.map[:map] = begin
                      map.map[:map].class == ActionController::Parameters ? map.map[:map].permit!.to_h : map.map[:map]
                    rescue StandardError
                      nil
                    end
    data = build_data(map, store)
    import_csv = ImportCsv.new
    result = import_csv.import(tenant, data.as_json.to_s)
    # check_or_assign_import_item(import_item)
    new_import_item = import_item
    import_item = begin
                    ImportItem.find(import_item.id)
                  rescue StandardError
                    new_import_item
                  end

    on_demand_logger = Logger.new("#{Rails.root}/log/import.log")
    on_demand_logger.info(result[:messages])
    update_status(import_item, result) if !store.csv_beta || result[:status] == false
    import_item.update_attributes(message: result[:messages]) unless result[:status]
  end

  def check_or_assign_import_item(import_item)
    return unless ImportItem.find_by_id(import_item.id).blank?

    import_item_id = import_item.id
    import_item = import_item.dup
    import_item.id = import_item_id
    import_item.save
  end

  def initiate_import_for(_store, import_item, handler)
    import_item.update_attributes(status: 'in_progress')
    result = Groovepacker::Stores::Context.new(handler).import_orders
    new_import_item = import_item
    begin
      import_item = begin
                      ImportItem.find(import_item.id)
                    rescue StandardError
                      new_import_item
                    end
      import_item.updated_orders_import = result[:previous_imported]
      import_item.success_imported = result[:success_imported]
      update_status(import_item, result)
    rescue StandardError
    end
  end

  def update_status(import_item, result)
    return if import_item.status == 'cancelled'

    status = result[:status] ? 'completed' : 'failed'
    import_item.update_attributes(status: status)
    import_summary = OrderImportSummary.top_summary
    import_summary&.emit_data_to_user(true)
  end

  def update_import_item_and_send_mail(e, import_item, tenant)
    import_item_message = 'Connection failed: Please verify store URL is https rather than http if the store is secure'
    import_item_message = "Import failed: #{e.message}" if e.message.strip != 'Error: 302'
    if import_item.store.store_type == 'Shipstation API 2' && e.message.include?('401')
      import_item_message = 'Authorization with Shipstation store failed. Please check your API credentials'
      import_item.update_attributes(status: 'failed', message: import_item_message, import_error: import_item_message)
    else
      error = begin
                ([e.message] << e.backtrace.first(3)).flatten.join(',')
              rescue StandardError
                e
              end
      import_item.update_attributes(status: 'failed', message: import_item_message, import_error: error)
      Rollbar.error(e, e.message, Apartment::Tenant.current)
    end
    check_and_restart_import(e, import_item, tenant)
  end

  def check_and_restart_import(e, import_item, tenant)
    ImportItem.where(status: 'not_started').update_all(status: 'cancelled')
    begin
      OrderImportSummary.top_summary.emit_data_to_user(true)
    rescue StandardError
      nil
    end
    import_start_count = $redis.get("import_restarted_#{tenant}").to_i || 0
    if import_start_count < 3
      $redis.set("import_restarted_#{tenant}", import_start_count.to_i + 1)
      $redis.expire("import_restarted_#{tenant}", 30.minutes.to_i)
      OrderImportSummary.create(user_id: nil, status: 'not_started')
      begin
        Groovepacker::Orders::Import.new(params_attrs: @import_params.with_indifferent_access, current_user: import_item.order_import_summary.user).start_import_for_all
      rescue StandardError
        nil
      end
    else
      $redis.del("import_restarted_#{tenant}")
      ImportMailer.failed(tenant: tenant, import_item: import_item, exception: e).deliver
    end
  end

  def start_shipwork_import(cred, _status, value, tenant)
    Apartment::Tenant.switch! tenant
    Time.use_zone(GeneralSetting.new_time_zone) do
      credential = ShipworksCredential.find(cred[:id])
      import_item = ImportItem.find_by_store_id(credential.store.id)
      shipwork_handler = Groovepacker::Stores::Handlers::ShipworksHandler.new(credential.store, import_item)
      context = Groovepacker::Stores::Context.new(shipwork_handler)
      context.import_order(value['ShipWorks']['Customer']['Order'])
      Tenant.save_se_import_data("========Shipworks Import Started UTC: #{Time.current.utc} TZ: #{Time.current}", '==Value', value)
    end
  end

  def import_product_from_store(tenant, store_id, product_import_type, product_import_range_days)
    Apartment::Tenant.switch! tenant
    Time.use_zone(GeneralSetting.new_time_zone) do
      store = Store.find store_id
      handler = get_handler_for_products(store)
      context = Groovepacker::Stores::Context.new(handler)
      if store.store_type == 'Shopify'
        context.import_shopify_products(product_import_type, product_import_range_days)
      elsif store.store_type == 'Shopline'
        context.import_shopline_products(product_import_type, product_import_range_days)
      else
        context.import_products
      end
    end
  end

  def get_handler_for_products(store)
    handler = nil
    case store.store_type
    when 'Ebay'
      handler = Groovepacker::Stores::Handlers::EbayHandler.new(store)
    when 'Magento'
      handler = Groovepacker::Stores::Handlers::MagentoHandler.new(store)
    when 'Magento API 2'
      handler = Groovepacker::Stores::Handlers::MagentoRestHandler.new(store)
    when 'Shipstation'
      handler = Groovepacker::Stores::Handlers::ShipstationHandler.new(store)
    when 'Shipstation API 2'
      handler = Groovepacker::Stores::Handlers::ShipstationRestHandler.new(store)
    when 'BigCommerce'
      handler = Groovepacker::Stores::Handlers::BigCommerceHandler.new(store)
    when 'Shopify'
      handler = Groovepacker::Stores::Handlers::ShopifyHandler.new(store)
    when 'Shopline'
      handler = Groovepacker::Stores::Handlers::ShoplineHandler.new(store)
    when 'Teapplix'
      handler = Groovepacker::Stores::Handlers::TeapplixHandler.new(store)
    when 'Amazon'
      handler = Groovepacker::Stores::Handlers::AmazonHandler.new(store)
    end
    handler
  end
end
