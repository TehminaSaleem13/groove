class AddClickScanToScanPackSettings < ActiveRecord::Migration
  def change
    add_column :scan_pack_settings, :click_scan, :boolean, :default => false
  end
end
