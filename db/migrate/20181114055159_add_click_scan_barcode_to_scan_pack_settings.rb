class AddClickScanBarcodeToScanPackSettings < ActiveRecord::Migration
  def change
    add_column :scan_pack_settings, :click_scan_barcode, :string, :default => 'CLICKSCAN'
  end
end
