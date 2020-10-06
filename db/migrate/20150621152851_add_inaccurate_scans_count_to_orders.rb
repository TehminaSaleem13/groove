class AddInaccurateScansCountToOrders < ActiveRecord::Migration[5.1]
  def change
    add_column :orders, :inaccurate_scan_count, :integer, default: 0
  end
end
