class ChangeCaptureImageOptionToBeStringInScanPackSettings < ActiveRecord::Migration[6.1]
  def up
    change_column :scan_pack_settings, :capture_image_option, :string, default: "do_not_take_image"
  end

  def down
    change_column :scan_pack_settings, :capture_image_option, :boolean, default: true
  end
end
