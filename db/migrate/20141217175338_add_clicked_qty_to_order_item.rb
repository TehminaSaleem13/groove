class AddClickedQtyToOrderItem < ActiveRecord::Migration[5.1]
  def change
    add_column :order_items, :clicked_qty, :integer, default: 0
  end
end
