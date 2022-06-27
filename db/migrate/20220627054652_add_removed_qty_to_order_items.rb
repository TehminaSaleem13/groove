class AddRemovedQtyToOrderItems < ActiveRecord::Migration[5.1]
  def change
    add_column :order_items, :removed_qty, :integer, default: 0
  end
end
