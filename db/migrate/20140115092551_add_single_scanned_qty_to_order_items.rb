class AddSingleScannedQtyToOrderItems < ActiveRecord::Migration[5.1]
  def change
    add_column :order_items, :single_scanned_qty, :integer, :default => 0
  end
end
