namespace :doo do
  desc "Schedule orders export email"
  task :schedule_orders_export_email => :environment do
  	failed_tenant = []
    tenants = Tenant.order(:name) rescue Tenant.all
    import_orders_obj = ImportOrders.new
    tenants.each do |tenant|
      begin
        import_orders_obj.reschedule_job('export_order', tenant.name)
        Apartment::Tenant.switch tenant.name
        export_settings = ExportSetting.all.first
        failed_tenant << tenant.name if Delayed::Job.where("queue LIKE ? and created_at >= ?", "%order_export_email_scheduled_#{tenant.name}%", DateTime.now.strftime('%F')).blank? && export_settings.present? && export_settings.auto_email_export? && export_settings.order_export_email.present? && export_settings.should_export_orders(DateTime.now + 1.day)
      rescue
      end
    end
	  ExportOrder.not_scheduled_emails(failed_tenant).deliver if failed_tenant.present?
    exit(1)
  end
end
