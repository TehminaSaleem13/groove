class LowInventoryLevel < ActionMailer::Base
  default from: "app@groovepacker.com"
  
  def notify(general_settings)
    attachments.inline['logo.png'] = 
      File.read("#{Rails.root}/public/images/logo.png")
    attachments.inline['caution_alert.png'] = 
      File.read("#{Rails.root}/public/images/caution_alert.png")
  	mail to: general_settings.low_inventory_email_address, 
  		subject: "GroovePacker Low Inventory Alert"
    import_orders_obj = ImportOrders.new
    import_orders_obj.reschedule_job('low_inventory_email')
  end
end
