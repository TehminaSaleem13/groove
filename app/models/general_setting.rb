class GeneralSetting < ActiveRecord::Base
  include SettingsHelper
  include AhoyEvent
  # attr_accessible :conf_req_on_notes_to_packer, :email_address_for_packer_notes,
  #                 :hold_orders_due_to_inventory,
  #                 :inventory_tracking, :low_inventory_alert_email,
  #                 :low_inventory_email_address, :time_to_send_email,
  #                 :packing_slip_message_to_customer, :product_weight_format,
  #                 :packing_slip_size, :packing_slip_orientation,
  #                 :strict_cc, :conf_code_product_instruction,
  #                 :conf_req_on_notes_to_packer, :email_address_for_packer_notes,
  #                 :hold_orders_due_to_inventory, :inventory_tracking,
  #                 :low_inventory_alert_email, :low_inventory_email_address,
  #                 :send_email_for_packer_notes, :default_low_inventory_alert_limit,
  #                 :email_address_for_billing_notification, :export_items,
  #                 :max_time_per_item, :send_email_on_mon,
  #                 :send_email_on_tue, :send_email_on_wed, :send_email_on_thurs,
  #                 :send_email_on_fri, :send_email_on_sat, :send_email_on_sun,
  #                 :scheduled_order_import, :time_to_import_orders,
  #                 :import_orders_on_mon, :import_orders_on_tue, :import_orders_on_wed,
  #                 :import_orders_on_thurs, :import_orders_on_fri, :import_orders_on_sat,
  #                 :import_orders_on_sun, :tracking_error_order_not_found,
  #                 :tracking_error_info_not_found, :custom_field_one,
  #                 :custom_field_two, :export_csv_email,
  #                 :show_primary_bin_loc_in_barcodeslip, :html_print,
  #                 :time_zone, :auto_detect, :schedule_import_mode, :master_switch, :idle_timeout, :hex_barcode,
  #                 :from_import, :to_import, :multi_box_shipments, :per_box_packing_slips,
  #                 :custom_user_field_one, :custom_user_field_two, :display_kit_parts, :remove_order_items, :create_barcode_at_import,
  #                 :print_post_scanning_barcodes, :print_packing_slips, :print_ss_shipping_labels, :per_box_shipping_label_creation,
  #                 :starting_value, :barcode_length, :show_sku_in_barcodeslip
  # validates_format_of :email_address_for_packer_notes, with: Devise.email_regexp, allow_blank: true
  validates :email_address_for_packer_notes, :format => { :with => /(\A([\w\.%\+\-]+)@([\w\-]+\.)+([\w]{2,})(,\s*([\w\.%\+\-]+)@([\w\-]+\.)+([\w]{2,}))*\z)/i }, :allow_blank => true
  after_save :send_low_inventory_alert_email
  after_save :scheduled_import
  after_update :inventory_state_change_check
  before_save :validate_params
  after_commit :log_events
  before_save :validate_barcode_length_and_starting_value
  @@all_tenants_settings = {}

  def validate_barcode_length_and_starting_value
    throw(:abort) if !self.barcode_length.positive? || !self.starting_value.to_i.positive? || self.starting_value.to_i.to_s.length > self.barcode_length
    self.starting_value = self.starting_value.to_s.ljust(self.barcode_length, '0') if self.starting_value.to_s.length < self.barcode_length
  end

  def log_events
    track_changes(title: 'General Settings Changed', tenant: Apartment::Tenant.current,
                  username: User.current.try(:username) || 'GP App', object_id: id, changes: saved_changes) if saved_changes.present? && saved_changes.keys != ['updated_at']
  end

  def validate_params
    if packing_slip_size == '4 x 6'
      self.packing_slip_orientation = 'portrait'
    end
    self.inventory_tracking = inventory_tracking.present?
    self.default_low_inventory_alert_limit = default_low_inventory_alert_limit.to_i
    self.default_low_inventory_alert_limit = 1 if default_low_inventory_alert_limit < 1
    self.max_time_per_item = max_time_per_item_was if max_time_per_item.blank?
    self.time_to_send_email = time_to_send_email_was if time_to_send_email.blank?
    self.time_to_import_orders = time_to_import_orders_was if time_to_import_orders.blank?
  end

  def self.get_custom_fields
    GeneralSetting.all.first.as_json(
      only: [
        :custom_field_one, :custom_field_two
        ]
    ).try(:values).try(:compact)
  end

  def self.time_zone
    time_zone = GeneralSetting.last.time_zone.to_i
    ApplicationController.new.check_for_dst(time_zone) ? time_zone + 3600 : time_zone
  end

  def self.new_time_zone
    time_zone = GeneralSetting.last&.new_time_zone
    time_zone = Time.find_zone(time_zone) ? time_zone : 'UTC'
    time_zone == 'UTC' ? 'Edinburgh' : time_zone # UTC Causes issues with Frontend
  end

  def self.setting
    if @@all_tenants_settings.nil?
      @@all_tenants_settings = {}
    end
    current_tenant = Apartment::Tenant.current
    if @@all_tenants_settings[current_tenant].nil?
      @@all_tenants_settings[current_tenant] = self.all.first
    end
    @@all_tenants_settings[current_tenant]
  end

  def self.unset_setting
    if @@all_tenants_settings.nil?
      @@all_tenants_settings = {}
    end
    @@all_tenants_settings[Apartment::Tenant.current] = nil
    true
  end

  def inventory_state_change_check
    changes = self.saved_changes
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

      bulk_actions.delay(:run_at => 2.seconds.from_now, :queue => 'inventory_process', priority: 95).process_all(Apartment::Tenant.current, groove_bulk_actions.id)
    else
      groove_bulk_actions.activity = 'disable'
      groove_bulk_actions.save

      bulk_actions.delay(:run_at => 2.seconds.from_now, :queue => 'inventory_unprocess', priority: 95).unprocess_all(Apartment::Tenant.current, groove_bulk_actions.id)
    end
    true
  end

  def scheduled_import
    result = Hash.new
    changed_hash = self.saved_changes
    if self.scheduled_order_import && !changed_hash[:time_to_import_orders].nil? && (changed_hash[:time_to_import_orders].map{ |time| time.strftime('%H:%M:%S')}.uniq.many? rescue nil)
      job_scheduled = false
      date = DateTime.now.in_time_zone
      for i in 0..6
        job_scheduled = self.schedule_job(date, self.time_to_import_orders, 'import_orders')
        date = date + 1.day
        break if job_scheduled
      end
    else
      tenant = Apartment::Tenant.current
      #Delayed::Job.where(queue: "import_orders_scheduled_#{tenant}").destroy_all
    end
    true
  end

  def should_import_orders_today
    day = DateTime.now.in_time_zone.strftime("%A")
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
    changed_hash = self.saved_changes
    if (self.inventory_tracking || self.low_inventory_alert_email) && !changed_hash['time_to_send_email'].nil? && !self.low_inventory_email_address.blank?
      job_scheduled = false
      date = DateTime.now.in_time_zone
      for i in 0..6
        job_scheduled = self.schedule_job(date,
                                          self.time_to_send_email, 'low_inventory_email')
        date = date + 1.day
        break if job_scheduled
      end
    else
      tenant = Apartment::Tenant.current
      Delayed::Job.where("queue LIKE ? and run_at >= ? and run_at <= ?", "low_inventory_email_scheduled_#{tenant}", DateTime.now().beginning_of_day, DateTime.now().end_of_day).destroy_all
    end
    true
  end

  def schedule_job (date, time, job_type)
    job_scheduled = false
    run_at_date = date
    run_at_date = run_at_date.change({:hour => time.hour, :min => time.min, :sec => time.sec})
    time_diff = ((run_at_date.to_time - Time.current)).to_i + Random.rand(120)
    #TODO: Disabled the dst for testing, some tenants are not receiving the reports.
    # time_diff -= 3600 if (Time.zone.now + time_diff.seconds).dst? && !Time.zone.now.dst?
    # time_diff += 3600 if !(Time.zone.now + time_diff.seconds).dst? && Time.zone.now.dst?
    time = time_diff.seconds.from_now
    time = time - 1.day if Time.current + 1.day < time
    if time_diff > 0
      tenant = Apartment::Tenant.current
      if job_type == 'low_inventory_email'
        if self.low_inventory_alert_email? && !self.low_inventory_email_address.blank? && self.should_send_email(time)
          Delayed::Job.where("queue LIKE ? and run_at >= ? and run_at <= ?", "low_inventory_email_scheduled_#{tenant}", time, time).destroy_all #unless self.changes.blank?
          # LowInventoryLevel.notify(self,tenant).deliver
          LowInventoryLevel.delay(:run_at => time, :queue => "low_inventory_email_scheduled_#{tenant}", priority: 95).notify(self, tenant)
          job_scheduled = true
        end
      elsif job_type == 'import_orders'
        if self.should_import_orders(date)
          Delayed::Job.where(queue: "import_orders_scheduled_#{tenant}").destroy_all
          self.delay(:run_at => time, :queue => "import_orders_scheduled_#{tenant}", priority: 95).import_orders_helper tenant
          job_scheduled = true
        end
      elsif job_type == 'export_order'
        export_setting = ExportSetting.all.first
        if export_setting.should_export_orders(time)
          existing_jobs = Delayed::Job.where("queue LIKE ? and run_at >= ? and run_at <= ?", "%order_export_email_scheduled_#{tenant}%", time.beginning_of_day , time.end_of_day)

          if existing_jobs.any?
            existing_jobs.destroy_all

            on_demand_logger = Logger.new("#{Rails.root}/log/order_export_reports.log")
            on_demand_logger.info('=========================================')
            log = { tenant: Apartment::Tenant.current, date: date, time: time, existing_jobs: existing_jobs.collect { |j| j.attributes.except('handler')}.to_json }
            on_demand_logger.info(log)
          end

          ExportSetting.update_all(manual_export: false)
          ExportOrder.delay(:run_at => time, :queue => "order_export_email_scheduled_#{tenant}", priority: 95).export(tenant)
          # ExportOrder.export(tenant).deliver
          job_scheduled = true
        end
      elsif job_type == 'stat_export'
        export_setting = ExportSetting.all.first
        if export_setting.should_stat_export_orders(time)
          Delayed::Job.where("queue LIKE ? and run_at >= ? and run_at <= ?", "%generate_stat_export_#{tenant}%", time.beginning_of_day , time.end_of_day).destroy_all
          ExportSetting.update_all(manual_export: false)
          params = {"duration"=>export_setting.stat_export_type.to_i, "email"=>export_setting.stat_export_email}
          stat_stream_obj = SendStatStream.new()
          stat_stream_obj.delay(:run_at => time, :queue => "generate_stat_export_#{tenant}", priority: 95).generate_export(tenant, params)
          job_scheduled = true
        end
      elsif job_type == 'daily_packed'
        export_setting = ExportSetting.all.first
        if export_setting.should_daily_export_orders(time)
          Delayed::Job.where("queue LIKE ? and run_at >= ? and run_at <= ?", "%generate_daily_packed_export_#{tenant}%", time.beginning_of_day , time.end_of_day).destroy_all
          ExportSetting.update_all(manual_export: false)
          daily_pack  = DailyPacked.new()
          daily_pack.delay(:run_at => time, :queue => "generate_daily_packed_export_#{tenant}", priority: 95).send_daily_pack_csv(tenant)
          job_scheduled = true
        end
      end

    end
    job_scheduled
  end

  def should_send_email_today
    day = DateTime.now.in_time_zone.strftime("%A")
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

  def per_tenant_settings
    current_tenant = Tenant.find_by_name(Apartment::Tenant.current)
    return {} unless current_tenant
    result = {}
    result[:scheduled_import_toggle] = current_tenant&.scheduled_import_toggle
    result[:inventory_report_toggle] = current_tenant&.inventory_report_toggle
    result[:is_multi_box] = current_tenant&.is_multi_box
    result[:api_call] = current_tenant&.api_call
    result[:allow_rts] = current_tenant&.allow_rts
    result[:product_ftp_import] = current_tenant&.product_ftp_import
    result[:groovelytic_stat] = current_tenant.groovelytic_stat rescue true
    result[:custom_product_fields] = current_tenant&.custom_product_fields
    result[:packing_cam] = current_tenant&.packing_cam
    result[:product_activity] = current_tenant&.product_activity_switch
    result
  end
end
