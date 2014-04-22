class LowInventoryLevel < ActionMailer::Base
  default from: "devtest@navaratan.com"
  
  def notify(general_settings)
  	mail to: general_settings.low_inventory_email_address, subject: "GroovePacker Low Inventory Alert"
  end
end
