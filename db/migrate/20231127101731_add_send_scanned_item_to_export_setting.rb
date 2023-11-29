class AddSendScannedItemToExportSetting < ActiveRecord::Migration[5.1]
  def change
    add_column :export_settings, :include_partially_scanned_orders_user_stats, :boolean, default: false
  end
end
