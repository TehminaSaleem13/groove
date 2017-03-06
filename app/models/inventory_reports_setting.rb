class InventoryReportsSetting < ActiveRecord::Base
  attr_accessible :send_email_on_mon, :send_email_on_tue, :send_email_on_wed, :send_email_on_thurs,  :send_email_on_fri,   :send_email_on_sat, :send_email_on_sun, :auto_email_report, :start_time, :end_time, :time_to_send_report_email, :report_email, :report_days_option
end
