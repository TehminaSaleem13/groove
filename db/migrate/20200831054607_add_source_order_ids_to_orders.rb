class AddSourceOrderIdsToOrders < ActiveRecord::Migration[5.1]
  def change
    add_column :orders, :source_order_ids, :text, default: nil
  end
end
