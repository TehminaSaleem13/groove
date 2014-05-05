class AddColumnsToGeneralSettings < ActiveRecord::Migration
  def change
    add_column :general_settings, :send_email_on_mon, :boolean, :default => false
    add_column :general_settings, :send_email_on_tue, :boolean, :default => false
    add_column :general_settings, :send_email_on_wed, :boolean, :default => false
    add_column :general_settings, :send_email_on_thurs, :boolean, :default => false
    add_column :general_settings, :send_email_on_fri, :boolean, :default => false
    add_column :general_settings, :send_email_on_sat, :boolean, :default => false
    add_column :general_settings, :send_email_on_sun, :boolean, :default => false
    add_column :general_settings, :time_to_send_email, :time, :default => '00:00:00'
  end
end
