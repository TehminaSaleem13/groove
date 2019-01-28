class AddLogCsv
  def add_log_csv(tenant,time_of_import,file_name)
    Apartment::Tenant.switch(tenant)
    @time_of_import = time_of_import
    @file_name = file_name
    n = Order.where('created_at > ?',$redis.get("last_order_#{tenant}")).count rescue 0
    @after_import_count = $redis.get("total_orders_#{tenant}").to_i + n

    time_zone = GeneralSetting.last.time_zone.to_i
    time_of_import_tz =  @time_of_import + time_zone

    orders = $redis.smembers("#{Apartment::Tenant.current}_csv_array")

    #on_demand_logger = Logger.new("#{Rails.root}/log/import_order_info_#{Apartment::Tenant.current}.log")
    log = {"Time_Stamp_Tenant_TZ" => "#{time_of_import_tz}","Time_Stamp_UTC" => "#{@time_of_import}" , "Tenant" => "#{Apartment::Tenant.current}","Name_of_imported_file" => "#{@file_name}","Orders_in_file" => "#{orders.count}".to_i, "New_orders_imported" => "#{$redis.get("new_order_#{tenant}")}".to_i, "Existing_orders_updated" =>"#{$redis.get("update_order_#{tenant}")}".to_i , "Existing_orders_skipped" => "#{$redis.get("skip_order_#{tenant}")}".to_i, "Orders_in_GroovePacker_before_import" => "#{$redis.get("total_orders_#{tenant}")}".to_i, "Orders_in_GroovePacker_after_import" =>"#{@after_import_count}".to_i }
    summary_params = {file_name: @file_name, import_type: "Order", log_record: log.to_json }
    summary = CsvImportSummary.create(summary_params)
    #on_demand_logger.info(log)
    #pdf_path = Rails.root.join( 'log', "import_order_info_#{Apartment::Tenant.current}.log")
    #reader_file_path = Rails.root.join('log', "import_order_info_#{Apartment::Tenant.current}.log")
    #base_file_name = File.basename(pdf_path)
    #pdf_file = File.open(reader_file_path)
    #GroovS3.create_log(Apartment::Tenant.current, base_file_name, pdf_path.read)
  end
end
