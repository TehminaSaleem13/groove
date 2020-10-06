class ChangeDefaultValueForScanPackSetting < ActiveRecord::Migration[5.1]
  def up
  	change_column :scan_pack_settings, :string_removal_enabled, :boolean, :default => false
  end

  def down
  	change_column :scan_pack_settings, :string_removal_enabled, :boolean, :default => true
  end
end
