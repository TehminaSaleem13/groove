class AddToteIdentifierToScanPackSetting < ActiveRecord::Migration[5.1]
  def change
    add_column :scan_pack_settings, :tote_identifier, :string, default: 'Tote'
  end
end
