class GeneralSetting < ActiveRecord::Base
  attr_accessible :conf_req_on_notes_to_packer, :email_address_for_packer_notes, :hold_orders_due_to_inventory,
   :inventory_tracking, :low_inventory_alert_email, :low_inventory_email_address, :send_email_for_packer_notes

  after_save :send_low_inventory_alert_email

  def self.get_packing_slip_message_to_customer
    self.all.first.packing_slip_message_to_customer
  end

  def self.get_product_weight_format
    self.all.first.product_weight_format
  end
  def self.get_packing_slip_size
    self.all.first.packing_slip_size
  end
  def self.get_packing_slip_orientation
    self.all.first.packing_slip_orientation
  end

  def send_low_inventory_alert_email
  	changed_hash = self.changes
    logger.info changed_hash
    if (self.inventory_tracking ||
        self.low_inventory_alert_email) &&
        !changed_hash['time_to_send_email'].nil?
      if self.should_send_email_today
        job_scheduled = false
        date = DateTime.now
        while !job_scheduled do
          job_scheduled = self.schedule_job(date)
          date = DateTime.now + 1.day
        end
      end
    end
  end

  def schedule_job (date)
    job_scheduled = false
    run_at_date = date.getutc
    run_at_date = run_at_date.change({:hour => self.time_to_send_email.hour, 
      :min => self.time_to_send_email.min, :sec => self.time_to_send_email.sec})
    time_diff = ((run_at_date - DateTime.now.getutc) * 24 * 60 * 60).to_i
    logger.info time_diff
    if time_diff > 0
      Delayed::Job.destroy_all
      #LowInventoryLevel.notify(self).deliver
      logger.info 'inserting delayed job'
      LowInventoryLevel.delay(:run_at => time_diff.seconds.from_now).notify(self)
      job_scheduled = true
    end
    job_scheduled
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

  def should_send_email(date)

    day = date.strftime("%A")
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
