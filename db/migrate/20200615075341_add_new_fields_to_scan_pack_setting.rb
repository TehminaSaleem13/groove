class AddNewFieldsToScanPackSetting < ActiveRecord::Migration
  def change
    add_column :scan_pack_settings, :single_item_order_complete_msg, :string, default: 'Labels Printing!'
    add_column :scan_pack_settings, :single_item_order_complete_msg_time, :float, :default => 4.0
    add_column :scan_pack_settings, :multi_item_order_complete_msg, :string, default: 'Collect all items from the tote!'
    add_column :scan_pack_settings, :multi_item_order_complete_msg_time, :float, :default => 4.0
  end
end
