class AddColumnToScanPackSettings < ActiveRecord::Migration[5.1]
  def change
    add_column :scan_pack_settings, :scanned, :boolean, :default => false 
    add_column :scan_pack_settings, :scanned_barcode, :string, :default => 'SCANNED'
  end
end
