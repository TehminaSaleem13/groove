namespace :doo do
  desc "Schedule orders export email"
  task :schedule_orders_export_email => :environment do
    tenants = Tenant.order(:name) rescue Tenant.all
    import_orders_obj = ImportOrders.new
    tenants.each do |tenant|
      import_orders_obj.reschedule_job('export_order', tenant.name) rescue nil
    end
    exit(1)
  end
end
