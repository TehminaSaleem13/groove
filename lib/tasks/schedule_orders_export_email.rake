namespace :doo do
  desc "Schedule orders export email"
  task :schedule_orders_export_email => :environment do
  	failed_tenant = []
    scheduled_tenants = []
    tenants = Tenant.order(:name) rescue Tenant.all
    tenants.each do |tenant|
      begin
        scheduled = ImportOrders.new.reschedule_job('export_order', tenant.name)
        scheduled_tenants << tenant.name if scheduled[0]
        Apartment::Tenant.switch tenant.name
        export_settings = ExportSetting.all.first
        setting = export_settings.present? && export_settings.auto_email_export? && export_settings.order_export_email.present? && export_settings.should_export_orders(DateTime.now + 1.day) 
        failed_tenant << tenant.name if Delayed::Job.where("queue LIKE ? and created_at >= ?", "%order_export_email_scheduled_#{tenant.name}%", DateTime.now.strftime('%F')).blank? && setting
        if failed_tenant.present?
          failed_tenant.each do |t|
            ImportOrders.new.reschedule_job('export_order', t)
          end
        end
      rescue
      end
    end
	  ExportOrder.not_scheduled_emails(failed_tenant, scheduled_tenants).deliver if failed_tenant.present? || scheduled_tenants.present?
    exit(1)
  end
end
