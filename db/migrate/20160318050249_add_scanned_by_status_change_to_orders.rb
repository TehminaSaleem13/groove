class AddScannedByStatusChangeToOrders < ActiveRecord::Migration[5.1]
  def change
    add_column :orders, :scanned_by_status_change, :boolean, :default => false
  end
end
