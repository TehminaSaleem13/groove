class AddToggleToScanPackSetting < ActiveRecord::Migration[5.1]
  def change
  	add_column :scan_pack_settings, :order_verification, :boolean, :default => false
  end
end
