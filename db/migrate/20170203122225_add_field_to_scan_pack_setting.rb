class AddFieldToScanPackSetting < ActiveRecord::Migration[5.1]
  def change
  	add_column :scan_pack_settings, :display_location, :boolean, :default => false
  end
end
