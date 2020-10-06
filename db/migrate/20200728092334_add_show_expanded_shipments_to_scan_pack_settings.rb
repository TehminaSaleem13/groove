class AddShowExpandedShipmentsToScanPackSettings < ActiveRecord::Migration[5.1]
  def up
    add_column :scan_pack_settings, :show_expanded_shipments, :boolean, default: true unless column_exists? :scan_pack_settings, :show_expanded_shipments
  end

  def down
    remove_column :scan_pack_settings, :show_expanded_shipments if column_exists? :scan_pack_settings, :show_expanded_shipments
  end
end
