class AddRecordLotNumberToScanPackSettings < ActiveRecord::Migration
  def change
    add_column :scan_pack_settings, :record_lot_number, :boolean, default: false
  end
end
