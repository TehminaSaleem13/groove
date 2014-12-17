class AddClickedQtyToOrderItem < ActiveRecord::Migration
  def change
    add_column :order_items, :clicked_qty, :integer, default: 0
  end
end
