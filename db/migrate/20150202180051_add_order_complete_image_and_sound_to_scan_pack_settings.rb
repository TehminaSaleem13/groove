class AddOrderCompleteImageAndSoundToScanPackSettings < ActiveRecord::Migration
  def change
    add_column :scan_pack_settings, :show_order_complete_image, :boolean, :default => true
    add_column :scan_pack_settings, :order_complete_image_src, :string, :default => '/assets/images/scan_order_complete.png'
    add_column :scan_pack_settings, :order_complete_image_time, :float, :default => 1.0
    add_column :scan_pack_settings, :play_order_complete_sound, :boolean, :default => true
    add_column :scan_pack_settings, :order_complete_sound_url, :string, :default => '/assets/sounds/scan_order_complete.mp3'
    add_column :scan_pack_settings, :complete_sound_sound_vol, :float, :default => 0.75
  end
end
