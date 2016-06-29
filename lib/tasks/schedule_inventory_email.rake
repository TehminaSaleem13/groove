namespace :doo do
  desc "Schedule inventory email"
  task :schedule_inventory_email => :environment do
    tenants = Tenant.order(:name) rescue Tenant.all
    import_orders_obj = ImportOrders.new
    tenants.each do |tenant|
      import_orders_obj.reschedule_job('low_inventory_email', tenant.name) rescue nil
    end
    exit(1)
  end
end
