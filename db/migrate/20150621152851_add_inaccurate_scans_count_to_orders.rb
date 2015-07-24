class AddInaccurateScansCountToOrders < ActiveRecord::Migration
  def change
    add_column :orders, :inaccurate_scan_count, :integer, default: 0
  end
end
