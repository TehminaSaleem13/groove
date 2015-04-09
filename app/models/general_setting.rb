class GeneralSetting < ActiveRecord::Base
  include SettingsHelper
  attr_accessible :conf_req_on_notes_to_packer, :email_address_for_packer_notes, :hold_orders_due_to_inventory,
   :inventory_tracking, :low_inventory_alert_email, :low_inventory_email_address, :send_email_for_packer_notes,
   :scheduled_order_import, :tracking_error_order_not_found, :tracking_error_info_not_found

  after_save :send_low_inventory_alert_email
  after_save :scheduled_import

  def scheduled_import
    result = Hash.new
    changed_hash = self.changes
    if self.scheduled_order_import && !changed_hash[:time_to_import_orders].nil?
      if self.should_import_orders_today
        job_scheduled = false
        date = DateTime.now
        while !job_scheduled do
          job_scheduled = self.schedule_job(date, 
            self.time_to_import_orders, 'import_orders')
          date = DateTime.now + 1.day
        end
      end
    end
  end

  def should_import_orders_today
    day = DateTime.now.strftime("%A")
    result = false
    if day=='Sunday' && self.import_orders_on_sun
      result = true
    elsif day=='Monday' && self.import_orders_on_mon
      result = true
    elsif day=='Tuesday' && self.import_orders_on_tue
      result = true
    elsif day=='Wednesday' && self.import_orders_on_wed
      result = true
    elsif day=='Thursday' && self.import_orders_on_thurs
      result = true
    elsif day=='Friday' && self.import_orders_on_fri
      result = true
    elsif day=='Saturday' && self.import_orders_on_sat
      result = true
    end
    result
  end
  
  def should_import_orders(date)
    day = date.strftime("%A")
    result = false
    if day=='Sunday' && self.import_orders_on_sun
      result = true
    elsif day=='Monday' && self.import_orders_on_mon
      result = true
    elsif day=='Tuesday' && self.import_orders_on_tue
      result = true
    elsif day=='Wednesday' && self.import_orders_on_wed
      result = true
    elsif day=='Thursday' && self.import_orders_on_thurs
      result = true
    elsif day=='Friday' && self.import_orders_on_fri
      result = true
    elsif day=='Saturday' && self.import_orders_on_sat
      result = true
    end
    result
  end

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
          job_scheduled = self.schedule_job(date, 
            self.time_to_send_email, 'low_inventory_email')
          date = DateTime.now + 1.day
        end
      end
    end
  end

  def schedule_job (date, time, job_type)
    job_scheduled = false
    run_at_date = date.getutc
    run_at_date = run_at_date.change({:hour => time.hour, 
      :min => time.min, :sec => time.sec})
    time_diff = ((run_at_date - DateTime.now.getutc) * 24 * 60 * 60).to_i
    logger.info time_diff
    if time_diff > 0
      tenant = Apartment::Tenant.current_tenant
      if job_type == 'low_inventory_email'
        Delayed::Job.where(queue: "low_inventory_email_scheduled_#{tenant}").destroy_all
        #LowInventoryLevel.notify(self,tenant).deliver
        logger.info 'inserting delayed job'
        LowInventoryLevel.delay(:run_at => time_diff.seconds.from_now,:queue => "low_inventory_email_scheduled_#{tenant}").notify(self,tenant)
        job_scheduled = true
      elsif job_type == 'import_orders'
        Delayed::Job.where(queue: "import_orders_scheduled_#{tenant}").destroy_all
        self.delay(:run_at => time_diff.seconds.from_now,:queue => "import_orders_scheduled_#{tenant}").import_orders_helper tenant
        job_scheduled = true
      end
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
