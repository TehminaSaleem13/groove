class LowInventoryLevel < ActionMailer::Base
  default from: "app@groovepacker.com"
  
  def notify(general_settings)
  	begin
	  	mail to: general_settings.low_inventory_email_address, 
	  		subject: "GroovePacker Low Inventory Alert"
  	rescue

  	end

  	date = DateTime.now
  	date = date + 1.day
  	job_scheduled = true

  	while !job_scheduled do
	   if general_settings.should_send_email(date)
	   	job_scheduled = general_settings.schedule_job(date)
	   else
	   	date = date + 1.day
	   end
		end
  end
end
