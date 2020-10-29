namespace :doo do
  desc "Schedule inventory email"
  task :schedule_inventory_email => :environment do
    if $redis.get("schedule_inventory_email").blank?
      $redis.set("schedule_inventory_email", true) 
      $redis.expire("schedule_inventory_email", 54) 
	    tenants = Tenant.where(is_cf: true).order(:name) rescue Tenant.where(is_cf: true)
	    import_orders_obj = ImportOrders.new
	    tenants.each do |tenant|
	    	import_orders_obj.reschedule_job('low_inventory_email', tenant.name) rescue nil
	    end
	  end
    exit(1)
  end
end
