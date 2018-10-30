class AddScanningSequenceToScanPackSetting < ActiveRecord::Migration
  def change
    add_column :scan_pack_settings, :scanning_sequence, :string, :default => "any_sequence"
  end
end
