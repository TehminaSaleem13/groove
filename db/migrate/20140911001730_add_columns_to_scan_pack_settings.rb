class AddColumnsToScanPackSettings < ActiveRecord::Migration
  def change
    add_column :scan_pack_settings, :show_success_image, :boolean, :default => true
    add_column :scan_pack_settings, :success_image_src, :string, :default => '/assets/images/scan_success.png'
    add_column :scan_pack_settings, :success_image_time, :float, :default => 1.5
    add_column :scan_pack_settings, :show_fail_image, :boolean, :default => true
    add_column :scan_pack_settings, :fail_image_src, :string, :default => '/assets/images/scan_fail.png'
    add_column :scan_pack_settings, :fail_image_time, :float, :default => 1.5
    add_column :scan_pack_settings, :play_success_sound, :boolean, :default => true
    add_column :scan_pack_settings, :success_sound_url, :string, :default => '/assets/sounds/scan_success.mp3'
    add_column :scan_pack_settings, :success_sound_vol, :float, :default => 0.75
    add_column :scan_pack_settings, :play_fail_sound, :boolean, :default => true
    add_column :scan_pack_settings, :fail_sound_url, :string, :default => '/assets/sounds/scan_fail.mp3'
    add_column :scan_pack_settings, :fail_sound_vol, :float, :default => 0.75
  end
end
