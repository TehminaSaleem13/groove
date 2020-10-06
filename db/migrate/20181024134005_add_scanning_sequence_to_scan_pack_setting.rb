class AddScanningSequenceToScanPackSetting < ActiveRecord::Migration[5.1]
  def change
    add_column :scan_pack_settings, :scanning_sequence, :string, :default => "any_sequence"
  end
end
