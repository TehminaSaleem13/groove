class ChangeColumnValueToScanPackSettings < ActiveRecord::Migration[5.1]
  def up
    change_column_default :scan_pack_settings, :partial_barcode, 'REMOVE-ALL'
    ScanPackSetting.update_all(partial_barcode: 'REMOVE-ALL')
  end

  def down
    change_column_default :scan_pack_settings, :partial_barcode, 'PARTIAL'
  end
end
