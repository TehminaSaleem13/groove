class AddTypeScanCodeToScanPackSettings < ActiveRecord::Migration
  def change
    add_column :scan_pack_settings, :type_scan_code_enabled, :boolean, :default=>true
    add_column :scan_pack_settings, :type_scan_code, :string, :default=>'*'
  end
end
