class AddColumnToScanPackSetting < ActiveRecord::Migration
  def change
  	add_column :scan_pack_settings, :download_ss_image, :boolean, :default => false
  end
end
