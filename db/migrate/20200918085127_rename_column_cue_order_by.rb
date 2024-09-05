class RenameColumnCueOrderBy < ActiveRecord::Migration[5.1]
  def up
    rename_column :scan_pack_settings, :scan_by_hex_number, :scan_by_packing_slip
    change_column :scan_pack_settings, :scan_by_packing_slip, :boolean, default: true
    rename_column :scan_pack_settings, :scan_by_tracking_number, :scan_by_shipping_label
    change_column :scan_pack_settings, :scan_by_shipping_label, :boolean, default: false
    ScanPackSetting.last.update(scan_by_packing_slip: true) if ScanPackSetting.last.present? && !ScanPackSetting.last.scan_by_packing_slip && !ScanPackSetting.last.scan_by_shipping_label
  end

  def down
    rename_column :scan_pack_settings, :scan_by_packing_slip, :scan_by_hex_number
    change_column :scan_pack_settings, :scan_by_hex_number, :boolean, default: true
    rename_column :scan_pack_settings, :scan_by_shipping_label, :scan_by_tracking_number
    change_column :scan_pack_settings, :scan_by_tracking_number, :boolean, default: false
  end
end
