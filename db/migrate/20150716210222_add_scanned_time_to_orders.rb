class AddScannedTimeToOrders < ActiveRecord::Migration
  def change
    add_column :orders, :total_scan_time, :integer, default: 0
    add_column :orders, :total_scan_count, :integer, default: 0
    add_column :orders, :packing_score, :decimal, default: 0
  end
end
