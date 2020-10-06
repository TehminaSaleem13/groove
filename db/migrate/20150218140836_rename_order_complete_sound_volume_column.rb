class RenameOrderCompleteSoundVolumeColumn < ActiveRecord::Migration[5.1]
  def change
    rename_column :scan_pack_settings, :complete_sound_sound_vol, :order_complete_sound_vol
  end
end
