class LowInventoryLevel < ActionMailer::Base
  default from: "app@groovepacker.com"
  
  def notify(general_settings)
    attachments.inline['logo.png'] = 
      File.read("#{Rails.root}/public/images/logo.png")
    attachments.inline['caution_alert.png'] = 
      File.read("#{Rails.root}/public/images/caution_alert.png")
  	mail to: general_settings.low_inventory_email_address, 
  		subject: "GroovePacker Low Inventory Alert"

  	date = DateTime.now
  	date = date + 1.day
  	job_scheduled = false

  	while !job_scheduled do
	   if general_settings.should_send_email(date)
	   	job_scheduled = general_settings.schedule_job(date,
        general_settings.time_to_send_email, 'low_inventory_email')
	   else
	   	date = date + 1.day
	   end
		end
  end
end
