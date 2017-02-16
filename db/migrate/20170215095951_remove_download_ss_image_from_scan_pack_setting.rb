class RemoveDownloadSsImageFromScanPackSetting < ActiveRecord::Migration
  def change
  	remove_column :scan_pack_settings, :download_ss_image
  end
end
