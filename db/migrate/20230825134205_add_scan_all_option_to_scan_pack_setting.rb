class AddScanAllOptionToScanPackSetting < ActiveRecord::Migration[5.1]
  def change
    add_column :scan_pack_settings, :scan_all_option, :boolean, :default => false
  end
end
