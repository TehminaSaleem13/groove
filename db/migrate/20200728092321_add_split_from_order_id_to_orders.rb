class AddSplitFromOrderIdToOrders < ActiveRecord::Migration[5.1]
  def up
    add_column :orders, :split_from_order_id, :text, default: nil unless column_exists? :orders, :split_from_order_id
  end

  def down
    remove_column :orders, :split_from_order_id if column_exists? :orders, :split_from_order_id
  end
end
