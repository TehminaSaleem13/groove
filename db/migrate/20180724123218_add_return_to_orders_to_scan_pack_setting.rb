class AddReturnToOrdersToScanPackSetting < ActiveRecord::Migration[5.1]
  def change
    add_column :scan_pack_settings, :return_to_orders, :boolean, :default => false
  end
end
