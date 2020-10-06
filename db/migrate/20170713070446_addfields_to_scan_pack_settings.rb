class AddfieldsToScanPackSettings < ActiveRecord::Migration[5.1]
  def change
  	add_column :scan_pack_settings, :string_removal_enabled, :boolean, :default => true
    add_column :scan_pack_settings, :string_removal, :string
    add_column :scan_pack_settings, :first_escape_string_enabled, :boolean, :default => false
    add_column :scan_pack_settings, :second_escape_string_enabled, :boolean, :default => false
    add_column :scan_pack_settings, :second_escape_string, :string
  end
end
