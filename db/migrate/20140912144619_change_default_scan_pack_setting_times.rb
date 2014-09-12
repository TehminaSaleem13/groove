class ChangeDefaultScanPackSettingTimes < ActiveRecord::Migration
  def up
    change_column :scan_pack_settings, :fail_image_time, :float, :default=> 1.0
    change_column :scan_pack_settings, :success_image_time, :float, :default=> 0.5
  end

  def down
    change_column :scan_pack_settings, :fail_image_time, :float, :default=> 1.5
    change_column :scan_pack_settings, :success_image_time, :float, :default=> 1.5
  end
end
