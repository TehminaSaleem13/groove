class ExportSetting < ActiveRecord::Base
  attr_accessible :auto_email_export, :time_to_send_export_email, :send_export_email_on_mon,
   :send_export_email_on_tue, :send_export_email_on_wed, :send_export_email_on_thu,
   :send_export_email_on_fri, :send_export_email_on_sat, :send_export_email_on_sun, 
   :last_exported, :export_orders_option, :order_export_type, :order_export_email 

  after_save :send_export_email
  after_save :scheduled_export

  def scheduled_export
    result = Hash.new
    changed_hash = self.changes
    if self.auto_email_export && !changed_hash[:time_to_send_export_email].nil?
      if self.should_export_orders_today
        job_scheduled = false
        date = DateTime.now
        while !job_scheduled do
          job_scheduled = self.schedule_job(date, 
            self.time_to_send_export_email)
          date = DateTime.now + 1.day
        end
      end
    end
  end

  def should_export_orders_today
    day = DateTime.now.strftime("%A")
    result = false
    if day=='Sunday' && self.send_export_email_on_sun
      result = true
    elsif day=='Monday' && self.send_export_email_on_mon
      result = true
    elsif day=='Tuesday' && self.send_export_email_on_tue
      result = true
    elsif day=='Wednesday' && self.send_export_email_on_wed
      result = true
    elsif day=='Thursday' && self.send_export_email_on_thu
      result = true
    elsif day=='Friday' && self.send_export_email_on_fri
      result = true
    elsif day=='Saturday' && self.send_export_email_on_sat
      result = true
    end
    result
  end

  def should_export_orders(date)
    day = date.strftime("%A")
    result = false
    if day=='Sunday' && self.send_export_email_on_sun
      result = true
    elsif day=='Monday' && self.send_export_email_on_mon
      result = true
    elsif day=='Tuesday' && self.send_export_email_on_tue
      result = true
    elsif day=='Wednesday' && self.send_export_email_on_wed
      result = true
    elsif day=='Thursday' && self.send_export_email_on_thu
      result = true
    elsif day=='Friday' && self.send_export_email_on_fri
      result = true
    elsif day=='Saturday' && self.send_export_email_on_sat
      result = true
    end
    result
  end

  def send_export_email
  	changed_hash = self.changes
    logger.info changed_hash
    if self.auto_email_export && !changed_hash['time_to_send_export_email'].nil?
      if self.should_export_orders_today
        job_scheduled = false
        date = DateTime.now
        while !job_scheduled do
          job_scheduled = self.schedule_job(date, 
            self.time_to_send_export_email)
          date = DateTime.now + 1.day
        end
      end
    end
  end

  def schedule_job (date, time)
    job_scheduled = false
    run_at_date = date.getutc
    run_at_date = run_at_date.change({:hour => time.hour, 
      :min => time.min, :sec => time.sec})
    time_diff = ((run_at_date - DateTime.now.getutc) * 24 * 60 * 60).to_i
    logger.info time_diff
    if time_diff > 0
      tenant = Apartment::Tenant.current_tenant
      Delayed::Job.where(queue: "order_export_email_scheduled_#{tenant}").destroy_all
      #LowInventoryLevel.notify(self,tenant).deliver
      logger.info 'inserting delayed job'
      ExportOrder.delay(:run_at => time_diff.seconds.from_now,:queue => "order_export_email_scheduled_#{tenant}").export(self,tenant)
      # ExportOrder.export(self,tenant)
      job_scheduled = true
    end
    job_scheduled
  end
end
