class AddScanStartTimeToOrders < ActiveRecord::Migration
  def change
    add_column :orders, :scan_start_time, :datetime, default: nil
  end
end
