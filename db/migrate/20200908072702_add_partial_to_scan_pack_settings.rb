class AddPartialToScanPackSettings < ActiveRecord::Migration
  def change
    add_column :scan_pack_settings, :partial, :boolean, default: false 
    add_column :scan_pack_settings, :partial_barcode, :string, default: 'PARTIAL'
  end
end
