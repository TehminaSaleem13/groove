class AddLocationDisplayFieldsToScanPackSetting < ActiveRecord::Migration[5.1]
  def change
    add_column :scan_pack_settings, :display_location2, :boolean, default: false
    add_column :scan_pack_settings, :display_location3, :boolean, default: false
  end
end
