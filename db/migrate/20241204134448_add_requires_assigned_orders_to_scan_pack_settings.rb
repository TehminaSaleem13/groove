class AddRequiresAssignedOrdersToScanPackSettings < ActiveRecord::Migration[6.1]
  def change
    add_column :scan_pack_settings, :requires_assigned_orders, :boolean, :default => false
  end
end
