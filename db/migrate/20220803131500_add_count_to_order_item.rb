class AddCountToOrderItem < ActiveRecord::Migration[5.1]
  def change
    add_column :order_items, :added_count, :integer, default: 0
  end
end
