class GeneralSetting < ActiveRecord::Base
  attr_accessible :conf_req_on_notes_to_packer, :email_address_for_packer_notes, :hold_orders_due_to_inventory,
   :inventory_tracking, :low_inventory_alert_email, :low_inventory_email_address, :send_email_for_packer_notes

  after_save :send_low_inventory_alert_email


  def send_low_inventory_alert_email
  	changed_hash = self.changes

    if (self.inventory_tracking ||
        self.low_inventory_alert_email)

    	if  self.should_send_email_today
    		LowInventoryLevel.delay(:run_at => self.time_to_send_email).notify(self)
    	end
    end
  end

  def should_send_email_today
	day = DateTime.now.strftime("%A")
  	result = false

  	if day == 'Monday' && self.send_email_on_mon
  		result = true
  	elsif day == 'Tuesday' && self.send_email_on_tue
  		result = true
  	elsif day == 'Wednesday' && self.send_email_on_wed
  		result = true
  	elsif day == 'Thursday' && self.send_email_on_thurs
  		result = true
  	elsif day == 'Friday' && self.send_email_on_fri
  		result = true
  	elsif day == 'Saturday' && self.send_email_on_sat
  		result = true
  	elsif day == 'Sunday' && self.send_email_on_sun
  		result = true
  	end
  	
  	result
  end
end
