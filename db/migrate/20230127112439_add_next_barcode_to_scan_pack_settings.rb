class AddNextBarcodeToScanPackSettings < ActiveRecord::Migration[5.1]
  def change
    add_column :scan_pack_settings, :add_next, :boolean, default: true
    add_column :scan_pack_settings, :add_next_barcode, :string, default: 'ADDNEXT'
  end
end
