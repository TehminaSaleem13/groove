class AddScannedByStatusChangeToOrders < ActiveRecord::Migration
  def change
    add_column :orders, :scanned_by_status_change, :boolean, :default => false
  end
end
