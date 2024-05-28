class AddColumnOrderNumberPrefixRemovalScanPackSetting < ActiveRecord::Migration[5.1]
  def change
    add_column :scan_pack_settings, :order_num_esc_str_removal, :string, default: ''
    add_column :scan_pack_settings, :order_num_esc_str_enabled, :boolean, default: false
  end
end
