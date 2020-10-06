class AddScanStartTimeToOrders < ActiveRecord::Migration[5.1]
  def change
    add_column :orders, :scan_start_time, :datetime, default: nil
  end
end
