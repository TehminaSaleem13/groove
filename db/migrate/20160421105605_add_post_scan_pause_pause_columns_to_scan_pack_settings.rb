class AddPostScanPausePauseColumnsToScanPackSettings < ActiveRecord::Migration[5.1]
  def change
    add_column :scan_pack_settings, :post_scan_pause_enabled, :boolean, :default => false
    add_column :scan_pack_settings, :post_scan_pause_time, :float, :default => 4.0
  end
end
