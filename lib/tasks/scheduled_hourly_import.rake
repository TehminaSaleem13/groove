namespace :doo do
  desc "Schedule Hourly Import"
  task :schedule_hourly_import => :environment do
    tenants = Tenant.where(scheduled_import_toggle: true)
    tenants.each do |tenant|
      Apartment::Tenant.switch tenant.name	
      setting = GeneralSetting.last
      day = DateTime.now.strftime("%A")
      result = false
      if day=='Sunday' && setting.import_orders_on_sun
        result = true
      elsif day=='Monday' && setting.import_orders_on_mon
        result = true
      elsif day=='Tuesday' && setting.import_orders_on_tue
        result = true
      elsif day=='Wednesday' && setting.import_orders_on_wed
        result = true
      elsif day=='Thursday' && setting.import_orders_on_thurs
        result = true
      elsif day=='Friday' && setting.import_orders_on_fri
        result = true
      elsif day=='Saturday' && setting.import_orders_on_sat
        result = true
      end

      if result == true
        order_summary_info = OrderImportSummary.new
        order_summary_info.user_id = nil
        order_summary_info.status = 'not_started'
        order_summary_info.save
        # ImportOrders.new.import_orders(tenant.name)
        import_orders_obj = ImportOrders.new
        import_orders_obj.delay(:run_at => 1.seconds.from_now,:queue => 'hourly import orders').import_orders(tenant.name)
      end
    end
    exit(1)
  end
end
