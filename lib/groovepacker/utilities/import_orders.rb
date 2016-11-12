class ImportOrders < Groovepacker::Utilities::Base
  include Connection

  def import_orders(tenant)
    Apartment::Tenant.switch(tenant)
    # we will remove all the jobs pertaining to import which are not started
    # we will also remove all the import summary which are not started.
    @order_import_summary = get_order_import_summary
    return if @order_import_summary.nil?
    # add import item for each store
    stores = Store.where("status = '1' AND store_type != 'system' AND store_type != 'Shipworks'")
    stores.each { |store| add_import_item_for_active_stores(store) } unless stores.blank?
    order_import_summaries.where("status!='in_progress' and id!=?", @order_import_summary.id).destroy_all
    initiate_import(tenant)
  end

  def add_import_item_for_active_stores(store)
    imp_items = ImportItem.where('store_id = ? AND order_import_summary_id IS NOT NULL', store.id)
    unless store.store_type == 'CSV' && store.ftp_credential && store.ftp_credential.use_ftp_import == false
      imp_items.delete_all
      new_import_item(store.id, nil, 'not_started')
      return
    end
    if imp_items.empty?
      new_import_item(store.id, 'CSV Importers Ready. FTP Order Import Is Off')
    elsif imp_items.where("status = 'failed'").present?
      imp_items.delete_all
      new_import_item(store.id, 'FTP Order Import Is Off')
    end
  end

  def initiate_import(tenant)
    #delete existing completed and cancelled order import summaries
    delete_existing_order_import_summaries
    return if @order_import_summary.nil? || @order_import_summary.id.nil?
    @order_import_summary.import_items.reload.find_each(:batch_size => 100) do |import_item|
      next if import_item.status == "cancelled"
      import_orders_with_import_item(import_item, tenant)
    end
    update_import_summary
  end

  def update_import_summary
    @order_import_summary.reload
    return if @order_import_summary.status == 'cancelled'
    @order_import_summary.update_attributes(status: 'completed')
  end

  # params should have hash of tenant, store, import_type = 'regular', user
  def import_order_by_store(params, result = {})
    Apartment::Tenant.switch(params[:tenant])
    if OrderImportSummary.where(status: 'in_progress').empty?
      run_import_for_single_store(params)
    else
      #import is already running. back off from importing
      result.merge({:status => false, :messages => "An import is already running."})
    end
    result
  end

  def run_import_for_single_store(params)
    Apartment::Tenant.switch(params[:tenant])
    #delete existing completed and cancelled order import summaries
    delete_existing_order_import_summaries
    #add a new import summary
    import_summary = OrderImportSummary.create( user: params[:user], status: 'not_started' )
    #add import item for the store
    ImportItem.where(store_id: params[:store].id).destroy_all
    import_summary.import_items.create(status: 'not_started', store: params[:store], import_type: params[:import_type], days: params[:days])
    #start importing using delayed job (ImportJob is defined in base class)
    Delayed::Job.enqueue ImportJob.new(params[:tenant], import_summary.id), :queue => 'importing_orders_'+ params[:tenant]

  end

  def reschedule_job(type, tenant)
    Apartment::Tenant.switch(tenant)
    date = DateTime.now + 1.day
    job_scheduled = false
    general_settings = GeneralSetting.all.first
    export_settings = ExportSetting.all.first
    schedule_a_job(type, date, job_scheduled, general_settings, export_settings)
  end

  def schedule_a_job(type, date, job_scheduled, general_settings, export_settings)
    should_schedule_job = false
    case type
    when 'import_orders'
      should_schedule_job, time = schedule_import_orders(general_settings, date)
    when 'low_inventory_email'
      should_schedule_job, time = schedule_low_inventory_email(general_settings, date, should_schedule_job)
    when 'export_order'
      should_schedule_job, time = schedule_export_order(export_settings, date, should_schedule_job)
    end
    job_scheduled, date = get_scheduled_job(should_schedule_job, general_settings, job_scheduled, date, time, type)

    return job_scheduled, date
  end

  def get_scheduled_job(should_schedule_job, general_settings, job_scheduled, date, time, type)
    if should_schedule_job
      job_scheduled = general_settings.schedule_job(date, time, type)
    else
      date = date + 1.day
    end
    return job_scheduled, date
  end

  def schedule_import_orders(general_settings, date)
    should_schedule_job = general_settings.should_import_orders(date)
    time = general_settings.time_to_import_orders
    return should_schedule_job, time
  end

  def schedule_low_inventory_email(general_settings, date, should_schedule_job, time=nil)
    if general_settings.low_inventory_alert_email? && general_settings.low_inventory_email_address.present?
      should_schedule_job = general_settings.should_send_email(date)
      time = general_settings.time_to_send_email
    end
    return should_schedule_job, time
  end

  def schedule_export_order(export_settings, date, should_schedule_job, time=nil)
    unless export_settings.auto_email_export? && export_settings.order_export_email.present?
      return should_schedule_job, time
    end
    should_schedule_job = export_settings.should_export_orders(date)
    time = export_settings.time_to_send_export_email
    return should_schedule_job, time
  end

  def import_orders_with_import_item(import_item, tenant)
    begin
      store_type = import_item.store.store_type
      store = import_item.store
      if store_type == 'CSV'
        initiate_csv_import(tenant, store_type, store, import_item) if import_item.status.present?
      else
        handler = get_handler(store_type, store, import_item)
        connection_successful = check_connection_for_shopify_or_bc(store, store_type, import_item)
        return unless connection_successful
        initiate_import_for(store, import_item, handler)
      end
    rescue Exception => e
      update_import_item_and_send_mail(e, import_item, tenant)
    end
  end

  def initiate_csv_import(tenant, store_type, store, import_item)
    mapping = CsvMapping.find_by_store_id(store.id)
    return unless check_connection_for_csv_import(mapping, store, import_item)
    import_item.update_attributes(status: 'in_progress')
    map = mapping.order_csv_map
    data = build_data(map,store)
    import_csv = ImportCsv.new
    result = import_csv.import(tenant, data.to_s)
    #check_or_assign_import_item(import_item)
    import_item = ImportItem.find_by_id(import_item.id) rescue import_item
    update_status(import_item, result)
    import_item.update_attributes(message: result[:messages]) unless result[:status]
  end

  def check_or_assign_import_item(import_item)
    return unless ImportItem.find_by_id(import_item.id).blank?
    import_item_id = import_item.id
    import_item = import_item.dup  
    import_item.id = import_item_id
    import_item.save
  end


  def initiate_import_for(store, import_item, handler)
    import_item.update_attributes(status: 'in_progress')
    result = Groovepacker::Stores::Context.new(handler).import_orders
    import_item = ImportItem.find_by_id(import_item.id) rescue import_item
    import_item.previous_imported = result[:previous_imported]
    import_item.success_imported = result[:success_imported]
    update_status(import_item, result)
  end

  def update_status(import_item, result)
    return if import_item.status == 'cancelled'
    status = result[:status] ? 'completed' : 'failed'
    import_item.update_attributes(status: status)
  end

  def update_import_item_and_send_mail(e, import_item, tenant)
    import_item_message = "Connection failed: Please verify store URL is https rather than http if the store is secure"
    import_item_message = "Import failed: #{e.message}" if e.message.strip != "Error: 302"
    import_item.update_attributes(status: 'failed', message: import_item_message, import_error: e)
    Rollbar.error(e, e.message)
    ImportMailer.failed({ tenant: tenant, import_item: import_item, exception: e }).deliver
  end
end
