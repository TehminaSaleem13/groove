class AddSkippedQtyToOrderItem < ActiveRecord::Migration[5.1]
  def change
    add_column :order_items, :skipped_qty, :integer, default: 0
  end
end
