class AddScanByTrackingNumberToScanPackSettings < ActiveRecord::Migration[5.1]
  def change
    add_column :scan_pack_settings, :scan_by_tracking_number, :boolean, :default=>false
  end
end
