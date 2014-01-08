class AddKitSplitToOrderItems < ActiveRecord::Migration
  def change
    add_column :order_items, :kit_split, :boolean, :default => false
  end
end
