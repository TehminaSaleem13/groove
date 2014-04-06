class LowInventoryLevel < ActionMailer::Base
  default from: "devtest@navaratan.com"
  
  def notify(product)
  	@product = product

 	mail to: GeneralSetting.all.first.low_inventory_email_address, subject: "GroovePacker Low Inventory Alert"
  end
end
