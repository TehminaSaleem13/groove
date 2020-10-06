class AddClickScanToScanPackSettings < ActiveRecord::Migration[5.1]
  def change
    add_column :scan_pack_settings, :click_scan, :boolean, :default => false
  end
end
