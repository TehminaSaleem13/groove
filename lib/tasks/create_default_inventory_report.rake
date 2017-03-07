namespace :doo do
  desc "Schedule orders export email"
  task :schedule_inventory_report => :environment do
    failed_tenant = []
    tenants = Tenant.order(:name) rescue Tenant.all
    tenants.each do |tenant|
    	begin	
    		Apartment::Tenant.switch tenant.name
    		ProductInventoryReport.create(name: "All_Products_Report", is_locked: true)
    		ProductInventoryReport.create(name: "All_Active_Products_Report", is_locked: true)
  		rescue
    	end
    end
    exit(1)
  end
end
