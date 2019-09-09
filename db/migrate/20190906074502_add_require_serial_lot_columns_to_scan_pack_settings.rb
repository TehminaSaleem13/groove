class AddRequireSerialLotColumnsToScanPackSettings < ActiveRecord::Migration
  def change
    add_column :scan_pack_settings, :require_serial_lot, :boolean, :default=>false
    add_column :scan_pack_settings, :valid_prefixes, :string
  end
end
