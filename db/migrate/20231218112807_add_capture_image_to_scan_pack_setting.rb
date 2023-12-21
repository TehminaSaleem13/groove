class AddCaptureImageToScanPackSetting < ActiveRecord::Migration[5.1]
  def change
    add_column :scan_pack_settings, :capture_image_option, :boolean, default: true
    add_column :scan_pack_settings, :email_reply, :string
  end
end
