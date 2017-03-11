namespace :doo do
  desc "Schedule inventory email"
  task :schedule_inventory_report => :environment do
    failed_tenant = []
    tenants = Tenant.order(:name) rescue Tenant.all
    tenants.each do |tenant|
    	begin	
    		Apartment::Tenant.switch tenant.name 
    		product_inv_setting = InventoryReportsSetting.last
		    day = DateTime.now.strftime("%A")
		    result = false
		    if day=='Sunday' && product_inv_setting.send_email_on_sun
		      result = true
		    elsif day=='Monday' && product_inv_setting.send_email_on_mon
		      result = true
		    elsif day=='Tuesday' && product_inv_setting.send_email_on_tue
		      result = true
		    elsif day=='Wednesday' && product_inv_setting.send_email_on_wed
		      result = true
		    elsif day=='Thursday' && product_inv_setting.send_email_on_thurs
		      result = true
		    elsif day=='Friday' && product_inv_setting.send_email_on_fri
		      result = true
		    elsif day=='Saturday' && product_inv_setting.send_email_on_sat
		      result = true
		    end
    		time = product_inv_setting.time_to_send_report_email
    		tenant_name = tenant.name
				InventoryReportMailer.delay(run_at: time.strftime("%H:%M:%S")).auto_inventory_report(false,nil,tenant_name) if result == true
    	rescue
    	end
    end
    exit(1)
  end
end
