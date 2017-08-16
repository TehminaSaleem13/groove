class AddToggleToScanPackSetting < ActiveRecord::Migration
  def change
  	add_column :scan_pack_settings, :order_verification, :boolean, :default => false
  end
end
