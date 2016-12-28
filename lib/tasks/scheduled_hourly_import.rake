namespace :doo do
  desc "Schedule Hourly Import"
  task :schedule_hourly_import => :environment do
    tenants = Tenant.where(scheduled_import_toggle: true)
    tenants.each do |tenant|
      Apartment::Tenant.switch tenant.name	
      setting = GeneralSetting.last
      result = setting.should_import_orders_today

      if result == true && setting.schedule_import_mode == "Hourly"
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
