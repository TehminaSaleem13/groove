class ChangeDefaultAlertEmailSetting < ActiveRecord::Migration
  def up
    change_column :general_settings, :default_low_inventory_alert_limit, :integer, :default => 1
    change_column :general_settings, :low_inventory_alert_email, :boolean, :default => false
  end

  def down
    change_column :general_settings, :default_low_inventory_alert_limit, :integer, :default => 0
    change_column :general_settings, :low_inventory_alert_email, :boolean, :default => true
  end
end
