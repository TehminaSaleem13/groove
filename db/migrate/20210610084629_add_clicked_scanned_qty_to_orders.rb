class AddClickedScannedQtyToOrders < ActiveRecord::Migration[5.1]
  def change
    add_column :orders, :clicked_scanned_qty, :integer
  end
end
