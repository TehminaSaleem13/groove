class CreateInventoryReportsSettings < ActiveRecord::Migration[5.1]
  def change
    create_table :inventory_reports_settings do |t|
		t.boolean  :send_email_on_mon,    :default => false,    :null => false
		t.boolean  :send_email_on_tue,    :default => false,    :null => false
		t.boolean  :send_email_on_wed,    :default => false,    :null => false
		t.boolean  :send_email_on_thurs,  :default => false,    :null => false
		t.boolean  :send_email_on_fri,    :default => false,    :null => false
		t.boolean  :send_email_on_sat,    :default => false,    :null => false
		t.boolean  :send_email_on_sun,    :default => false,    :null => false
		t.boolean  :auto_email_report,    :default => false,    :null => false
		t.datetime :start_time
		t.datetime :end_time
		t.datetime :time_to_send_report_email
		t.string   :report_email
        t.timestamps
    end
  end
end


