class AddFieldToScanPackSetting < ActiveRecord::Migration
  def change
  	add_column :scan_pack_settings, :display_location, :boolean, :default => false
  end
end
