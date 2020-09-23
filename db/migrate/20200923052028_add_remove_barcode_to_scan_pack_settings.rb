class AddRemoveBarcodeToScanPackSettings < ActiveRecord::Migration[5.1]
  def change
    add_column :scan_pack_settings, :remove_enabled, :boolean, default: false
    add_column :scan_pack_settings, :remove_barcode, :string, default: 'REMOVE'
  end
end
