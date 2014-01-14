class AddKitSplitQtyToOrderItems < ActiveRecord::Migration
  def change
    add_column :order_items, :kit_split_qty, :integer, :default => 0
  end
end
