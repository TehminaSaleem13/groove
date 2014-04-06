class AddDefaultLowInventoryAlertLimit < ActiveRecord::Migration
  def change
    add_column :general_settings, :default_low_inventory_alert_limit, :integer, :default=>0
  end
end
