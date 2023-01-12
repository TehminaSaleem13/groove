class AddPassScanBarcodeToScanPackSettings < ActiveRecord::Migration[5.1]
  def change
    add_column :scan_pack_settings, :pass_scan, :boolean, default: true
    add_column :scan_pack_settings, :pass_scan_barcode, :string, default: 'PASS'
  end
end
