class AddToteIdentifierToScanPackSetting < ActiveRecord::Migration
  def change
    add_column :scan_pack_settings, :tote_identifier, :string, default: 'Tote'
  end
end
