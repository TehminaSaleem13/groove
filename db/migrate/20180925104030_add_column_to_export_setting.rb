class AddColumnToExportSetting < ActiveRecord::Migration
  def change
    add_column :export_settings, :daily_packed_email_export, :boolean, :default => true
    add_column :export_settings, :time_to_send_daily_packed_export_email, :datetime
    add_column :export_settings, :daily_packed_email_on_mon, :boolean, :default => false
    add_column :export_settings, :daily_packed_email_on_tue, :boolean, :default => false
    add_column :export_settings, :daily_packed_email_on_wed, :boolean, :default => false
    add_column :export_settings, :daily_packed_email_on_thu, :boolean, :default => false
    add_column :export_settings, :daily_packed_email_on_fri, :boolean, :default => false
    add_column :export_settings, :daily_packed_email_on_sat, :boolean, :default => false
    add_column :export_settings, :daily_packed_email_on_sun, :boolean, :default => false
    add_column :export_settings, :daily_packed_export_type, :string, :default => '30'
    add_column :export_settings, :daily_packed_email, :string
  end
end
