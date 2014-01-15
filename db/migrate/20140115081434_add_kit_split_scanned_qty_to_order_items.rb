class AddKitSplitScannedQtyToOrderItems < ActiveRecord::Migration
  def change
    add_column :order_items, :kit_split_scanned_qty, :integer, :default=>0
  end
end
