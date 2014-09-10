class ChangeDefaultsScanPackSettings < ActiveRecord::Migration
  def up
    change_column :scan_pack_settings, :enable_click_sku, :boolean, :default=>true
    change_column :scan_pack_settings, :ask_tracking_number, :boolean, :default=>false
  end

  def down
    change_column :scan_pack_settings, :enable_click_sku, :boolean, :default=>false
    change_column :scan_pack_settings, :ask_tracking_number, :boolean, :default=>true
  end
end
