class AddTrackingNumberValidationToScanPackSettings < ActiveRecord::Migration[5.1]
  def up
    add_column :scan_pack_settings, :tracking_number_validation_enabled, :boolean, :default => false
    add_column :scan_pack_settings, :tracking_number_validation_prefixes, :string
  end

  def down
    remove_column :scan_pack_settings, :tracking_number_validation_enabled
    remove_column :scan_pack_settings, :tracking_number_validation_prefixes
  end
end
