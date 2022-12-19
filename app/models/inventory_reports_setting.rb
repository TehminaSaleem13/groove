# frozen_string_literal: true

class InventoryReportsSetting < ActiveRecord::Base
  # attr_accessible :send_email_on_mon, :send_email_on_tue, :send_email_on_wed, :send_email_on_thurs,  :send_email_on_fri,   :send_email_on_sat, :send_email_on_sun, :auto_email_report, :start_time, :end_time, :time_to_send_report_email, :report_email, :report_days_option

  after_save :scheduled_inv_report

  def scheduled_inv_report
    if auto_email_inv_report_with_changed_hash
      schedule_job_inv_report('inv_report', time_to_send_report_email)
    else
      destroy_inv_report_email_scheduled
    end
  end

  def should_inv_report(date)
    day = date.strftime('%a')
    # Returns True/False
    day == 'Thu' ? send("send_email_on_#{day.downcase}rs") : send("send_email_on_#{day.downcase}")
  end

  private

  def schedule_job_inv_report(type, time)
    job_scheduled = false
    date = DateTime.now.in_time_zone
    inv_report_settings = GeneralSetting.all.first
    7.times do
      job_scheduled = inv_report_settings.schedule_job(
        date, time, type
      )
      date += 1.day
      break if job_scheduled
    end
  end

  def auto_email_inv_report_with_changed_hash
    report_email.present? && saved_change_to_time_to_send_report_email.present?
  end

  def destroy_inv_report_email_scheduled
    tenant = Apartment::Tenant.current
    Delayed::Job.where('queue =? && run_at < ?', "schedule_inventory_report_#{tenant}", Time.current).destroy_all
  end
end
