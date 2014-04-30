class LowInventoryLevel < ActionMailer::Base
  default from: "devtest@navaratan.com"
  
  def notify(general_settings)
  	mail to: general_settings.low_inventory_email_address, subject: "GroovePacker Low Inventory Alert"

  	date = DateTime.now
  	date = date + 1.day
  	job_scheduled = false

  	while !job_scheduled do
	   if general_settings.should_send_email(date)
	   	logger.info 'Scheduling next job'
	   	general_settings.schedule_job(date)
	   	job_scheduled = true
	   else
	   	date = date + 1.day
	   end
	end
  end
end
