class GeneralSetting < ActiveRecord::Base
  include SettingsHelper
  attr_accessible :conf_req_on_notes_to_packer, :email_address_for_packer_notes, :hold_orders_due_to_inventory,
                  :inventory_tracking, :low_inventory_alert_email, :low_inventory_email_address, :send_email_for_packer_notes,
                  :scheduled_order_import, :tracking_error_order_not_found, :tracking_error_info_not_found, :product_weight_format,
                  :packing_slip_size, :packing_slip_orientation, :time_to_import_orders, :time_to_send_email, :import_orders_on_mon,
                  :import_orders_on_tue, :import_orders_on_wed, :import_orders_on_thurs, :import_orders_on_fri, :import_orders_on_sat,
                  :import_orders_on_sun

  after_save :send_low_inventory_alert_email
  after_save :scheduled_import
  after_update :inventory_state_change_check
  @@all_tenants_settings = {}

  def self.setting
    if @@all_tenants_settings.nil?
      @@all_tenants_settings = {}
    end
    if @@all_tenants_settings[Apartment::Tenant.current].nil?
      @@all_tenants_settings[Apartment::Tenant.current] = self.all.first
    end
    @@all_tenants_settings[Apartment::Tenant.current]
  end

  def self.unset_setting
    if @@all_tenants_settings.nil?
      @@all_tenants_settings = {}
    end
    @@all_tenants_settings[Apartment::Tenant.current] = nil
    true
  end

  def inventory_state_change_check
    changes = self.changes
    GeneralSetting.unset_setting
    if changes.nil? || changes['inventory_tracking'].nil?
      return true
    end

    bulk_actions = Groovepacker::Inventory::BulkActions.new
    groove_bulk_actions = GrooveBulkActions.new
    groove_bulk_actions.identifier = 'inventory'
    if changes['inventory_tracking'][1]

      groove_bulk_actions.activity = 'enable'
      groove_bulk_actions.save

      bulk_actions.delay(:run_at => 10.seconds.from_now).process_all(Apartment::Tenant.current, groove_bulk_actions.id)
    else
      groove_bulk_actions.activity = 'disable'
      groove_bulk_actions.save

      bulk_actions.delay(:run_at => 10.seconds.from_now).unprocess_all(Apartment::Tenant.current, groove_bulk_actions.id)
    end
    true
  end

  def scheduled_import
    result = Hash.new
    changed_hash = self.changes
    if self.scheduled_order_import && !changed_hash[:time_to_import_orders].nil?
      job_scheduled = false
      date = DateTime.now
      for i in 0..6
        job_scheduled = self.schedule_job(date,
                                          self.time_to_import_orders, 'import_orders')
        date = date + 1.day
        break if job_scheduled
      end
    else
      tenant = Apartment::Tenant.current
      Delayed::Job.where(queue: "import_orders_scheduled_#{tenant}").destroy_all
    end
    true
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
    if (self.inventory_tracking ||
      self.low_inventory_alert_email) &&
      !changed_hash['time_to_send_email'].nil? &&
      !self.low_inventory_email_address.blank?
      job_scheduled = false
      date = DateTime.now
      for i in 0..6
        job_scheduled = self.schedule_job(date,
                                          self.time_to_send_email, 'low_inventory_email')
        date = date + 1.day
        break if job_scheduled
      end
    else
      tenant = Apartment::Tenant.current
      Delayed::Job.where(queue: "low_inventory_email_scheduled_#{tenant}").destroy_all
    end
    true
  end

  def schedule_job (date, time, job_type)
    job_scheduled = false
    run_at_date = date.getutc
    run_at_date = run_at_date.change({:hour => time.hour,
                                      :min => time.min, :sec => time.sec})
    time_diff = ((run_at_date - DateTime.now.getutc) * 24 * 60 * 60).to_i
    if time_diff > 0
      tenant = Apartment::Tenant.current
      if job_type == 'low_inventory_email'
        if self.low_inventory_alert_email? && !self.low_inventory_email_address.blank? && self.should_send_email(date)
          Delayed::Job.where(queue: "low_inventory_email_scheduled_#{tenant}").destroy_all
          #LowInventoryLevel.notify(self,tenant).deliver
          LowInventoryLevel.delay(:run_at => time_diff.seconds.from_now, :queue => "low_inventory_email_scheduled_#{tenant}").notify(self, tenant)
          job_scheduled = true
        end
      elsif job_type == 'import_orders'
        if self.should_import_orders(date)
          Delayed::Job.where(queue: "import_orders_scheduled_#{tenant}").destroy_all
          self.delay(:run_at => time_diff.seconds.from_now, :queue => "import_orders_scheduled_#{tenant}").import_orders_helper tenant
          job_scheduled = true
        end
      elsif job_type == 'export_order'
        export_setting = ExportSetting.all.first
        if export_setting.should_export_orders(date)
          Delayed::Job.where(queue: "order_export_email_scheduled_#{tenant}").destroy_all
          ExportOrder.delay(:run_at => time_diff.seconds.from_now, :queue => "order_export_email_scheduled_#{tenant}").export(tenant)
          # ExportOrder.export(tenant).deliver
          job_scheduled = true
        end
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
