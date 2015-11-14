class ImportOrders
  def import_orders(tenant)
    Apartment::Tenant.switch(tenant)
    result = Hash.new
    # we will remove all the jobs pertaining to import which are not started

    # we will also remove all the import summary which are not started.
    if OrderImportSummary.where(status: 'in_progress').empty?
      order_import_summaries = OrderImportSummary.where(status: 'not_started')
      if !order_import_summaries.empty?
        ordered_import_summaries = order_import_summaries.order('updated_at' + ' ' + 'desc')
        ordered_import_summaries.each do |order_import_summary|
          if order_import_summary == ordered_import_summaries.first
            order_import_summary.status = 'in_progress'
            order_import_summary.save
            ImportItem.where('order_import_summary_id IS NOT NULL').delete_all
            # add import item for each store
            stores = Store.where("status = '1' AND store_type != 'system' AND store_type != 'Shipworks'")
            if stores.length != 0
              stores.each do |store|
                import_item = ImportItem.new
                import_item.store_id = store.id
                import_item.status = 'not_started'
                import_item.order_import_summary_id = order_import_summary.id
                import_item.save
              end
            end
            @order_import_summary = order_import_summary
          elsif order_import_summary.status != 'in_progress'
            order_import_summary.delete
          end
        end
      end
      OrderImportSummary.where(status: 'completed').delete_all
      OrderImportSummary.where(status: 'cancelled').delete_all
      if !@order_import_summary.nil? && !@order_import_summary.id.nil?
        import_items = @order_import_summary.import_items
        import_items.each do |import_item|
          import_orders_with_import_item(import_item, tenant)
        end
        @order_import_summary.reload
        if @order_import_summary.status != 'cancelled'
          @order_import_summary.status = 'completed'
          @order_import_summary.save
        end
      end
    end
    result
  end

  def init_import(tenant)
    Apartment::Tenant.switch(tenant)
  end

  # params should have hash of tenant, store, import_type = 'regular', user
  def import_order_by_store(params)
    result = {
      status: true,
      messages: []
    }
    tenant = params[:tenant]
    store = params[:store]
    import_type = params[:import_type]
    user = params[:user]
    Apartment::Tenant.switch(tenant)
    if OrderImportSummary.where(status: 'in_progress').empty?
      #delete existing order import summary
      OrderImportSummary.where(status: 'completed').delete_all
      OrderImportSummary.where(status: 'cancelled').delete_all
      #add a new import summary
      import_summary = OrderImportSummary.create(
        user: user,
        status: 'not_started'
      )

      #add import item for the store
      import_summary.import_items.create(
        store: store,
        import_type: import_type
      )

      #start importing using delayed job
      Delayed::Job.enqueue ImportJob.new(tenant, import_summary.id), :queue => 'importing_orders_'+ tenant
    else
      #import is already running. back off from importing
      result[:status] = false
      result[:messages] << "An import is already running."
    end
    result
  end

  def reschedule_job(type, tenant)
    Apartment::Tenant.switch(tenant)
    date = DateTime.now
    date = date + 1.day
    job_scheduled = false
    general_settings = GeneralSetting.all.first
    export_settings = ExportSetting.all.first
    for i in 0..6
      should_schedule_job = false
      if type=='import_orders'
        should_schedule_job = general_settings.should_import_orders(date)
        time = general_settings.time_to_import_orders
      elsif type=='low_inventory_email'
        if general_settings.low_inventory_alert_email? && !general_settings.low_inventory_email_address.blank?
          should_schedule_job = general_settings.should_send_email(date)
          time = general_settings.time_to_send_email
        end
      elsif type == 'export_order'
        if export_settings.auto_email_export? && !export_settings.order_export_email.blank?
          should_schedule_job = export_settings.should_export_orders(date)
          time = export_settings.time_to_send_export_email
        end
      end

      if should_schedule_job
        job_scheduled = general_settings.schedule_job(date,
                                                      time, type)
      else
        date = date + 1.day
      end
      break if job_scheduled
    end
  end

  def import_orders_with_import_item(import_item, tenant)
    begin
      store_type = import_item.store.store_type
      store = import_item.store
      if store_type == 'Amazon'
        import_item.status = 'in_progress'
        import_item.save
        context = Groovepacker::Stores::Context.new(
          Groovepacker::Stores::Handlers::AmazonHandler.new(store, import_item))
        result = context.import_orders
        import_item.previous_imported = result[:previous_imported]
        import_item.success_imported = result[:success_imported]
        if !result[:status]
          import_item.status = 'failed'
        else
          import_item.status = 'completed'
        end
        import_item.save
      elsif store_type == 'Ebay'
        import_item.status = 'in_progress'
        import_item.save
        context = Groovepacker::Stores::Context.new(
          Groovepacker::Stores::Handlers::EbayHandler.new(store, import_item))
        result = context.import_orders
        import_item.previous_imported = result[:previous_imported]
        import_item.success_imported = result[:success_imported]
        if !result[:status]
          import_item.status = 'failed'
        else
          import_item.status = 'completed'
        end
        import_item.save
      elsif store_type == 'Magento'
        import_item.status = 'in_progress'
        import_item.save
        context = Groovepacker::Stores::Context.new(
          Groovepacker::Stores::Handlers::MagentoHandler.new(store, import_item))
        result = context.import_orders
        import_item.previous_imported = result[:previous_imported]
        import_item.success_imported = result[:success_imported]
        if !result[:status]
          import_item.status = 'failed'
        else
          import_item.status = 'completed'
        end
        import_item.save
      elsif store_type == 'Shipstation'
        import_item.status = 'in_progress'
        import_item.save
        context = Groovepacker::Stores::Context.new(
          Groovepacker::Stores::Handlers::ShipstationHandler.new(store, import_item))
        result = context.import_orders
        import_item.previous_imported = result[:previous_imported]
        import_item.success_imported = result[:success_imported]
        if !result[:status]
          import_item.status = 'failed'
        else
          import_item.status = 'completed'
        end
        import_item.save
      elsif store_type == 'Shipstation API 2'
        import_item.status = 'in_progress'
        import_item.save
        context = Groovepacker::Stores::Context.new(
          Groovepacker::Stores::Handlers::ShipstationRestHandler.new(store, import_item))
        result = context.import_orders
        import_item.reload
        import_item.previous_imported = result[:previous_imported]
        import_item.success_imported = result[:success_imported]
        if import_item.status != 'cancelled'
          if !result[:status]
            import_item.status = 'failed'
          else
            import_item.status = 'completed'
          end
        end
        import_item.save
      elsif store_type == 'Shopify'
        import_item.status = 'in_progress'
        import_item.save
        context = Groovepacker::Stores::Context.new(
          Groovepacker::Stores::Handlers::ShopifyHandler.new(store, import_item))
        result = context.import_orders
        import_item.reload
        import_item.previous_imported = result[:previous_imported]
        import_item.success_imported = result[:success_imported]
        if import_item.status != 'cancelled'
          if !result[:status]
            import_item.status = 'failed'
          else
            import_item.status = 'completed'
          end
        end
        import_item.save

      #=====================BigCommerce Orders Import======================
      elsif store_type == 'BigCommerce'
        import_item.status = 'in_progress'
        import_item.save
        context = Groovepacker::Stores::Context.new(
          Groovepacker::Stores::Handlers::BigCommerceHandler.new(store, import_item))
        result = context.import_orders
        import_item.reload
        import_item.previous_imported = result[:previous_imported]
        import_item.success_imported = result[:success_imported]
        if import_item.status != 'cancelled'
          if !result[:status]
            import_item.status = 'failed'
          else
            import_item.status = 'completed'
          end
        end
        import_item.save
      #=============================================================
      elsif store_type == 'CSV'
        mapping = CsvMapping.find_by_store_id(store.id)
        unless mapping.nil? || mapping.order_csv_map.nil? || store.ftp_credential.nil? || (!store.ftp_credential.connection_established)
          import_item.status = 'in_progress'
          import_item.save
          map = mapping.order_csv_map
          data = build_data(map,store)
          
          import_csv = ImportCsv.new
          result = import_csv.import(tenant, data.to_s)

          import_item.reload
          if import_item.status != 'cancelled'
            if !result[:status]
              import_item.status = 'failed'
              import_item.message = result[:messages]
            else
              import_item.status = 'completed'
            end
          end
        else
          import_item.status = 'failed'
          import_item.message = "connection not established or no maps selected for the csv store"
        end
        import_item.save
      end
    rescue Exception => e
      if e.message.strip == "Error: 302"
        import_item.message = "Connection failed: Please verify store URL is https rather than http if the store is secure"
      else
        import_item.message = "Import failed: " + e.message
      end
      import_item.status = 'failed'
      import_item.save
      ImportMailer.failed({
        tenant: tenant, 
        import_item: import_item, 
        exception: e
      }).deliver
    end
  end

  def build_data(map,store)
    data = {}
    data[:flag] = "ftp_download"
    data[:type] = "order"
    data[:fix_width] = map[:map][:fix_width]
    data[:fixed_width] = map[:map][:fixed_width]
    data[:sep] = map[:map][:sep]
    data[:delimiter] = map[:map][:delimiter]
    data[:rows] = map[:map][:rows]
    data[:map] = map[:map][:map]
    data[:store_id] = store.id
    data[:import_action] = map[:map][:import_action]
    data[:contains_unique_order_items] = map[:map][:contains_unique_order_items]
    data[:generate_barcode_from_sku] = map[:map][:generate_barcode_from_sku]
    data[:use_sku_as_product_name] = map[:map][:use_sku_as_product_name]
    data[:order_placed_at] = map[:map][:order_placed_at]
    data[:order_date_time_format] = map[:map][:order_date_time_format]
    data[:day_month_sequence] = map[:map][:day_month_sequence]
      
    return data
  end

  ImportJob = Struct.new(:tenant, :order_import_summary_id) do
    def perform
      Apartment::Tenant.switch(tenant)

      order_import_summary = OrderImportSummary.find(order_import_summary_id)
      order_import_summary.status = 'in_progress'
      order_import_summary.save

      order_import_summary.import_items.each do |import_item|
        ImportOrders.new.import_orders_with_import_item(import_item, tenant)
      end
      order_import_summary.reload
      if order_import_summary.status != 'cancelled'
        order_import_summary.status = 'completed'
        order_import_summary.save
      end
    end
  end
end
