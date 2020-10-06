class AddIndexesForScanPack < ActiveRecord::Migration[5.1]
  def change
    add_index :order_items, [:inv_status, :scanned_status]
    add_index :orders, [:status]
  end
end
