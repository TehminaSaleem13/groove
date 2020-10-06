class RemoveDownloadSsImageFromScanPackSetting < ActiveRecord::Migration[5.1]
  def change
  	remove_column :scan_pack_settings, :download_ss_image
  end
end
