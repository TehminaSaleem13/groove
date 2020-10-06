class AddKitSplitToOrderItems < ActiveRecord::Migration[5.1]
  def change
    add_column :order_items, :kit_split, :boolean, :default => false
  end
end
