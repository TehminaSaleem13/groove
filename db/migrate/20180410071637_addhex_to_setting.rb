class AddhexToSetting < ActiveRecord::Migration
  def change
  	add_column :scan_pack_settings, :scan_by_hex_number, :boolean, default: false
  end
end
