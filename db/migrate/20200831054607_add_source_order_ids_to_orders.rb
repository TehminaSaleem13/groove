class AddSourceOrderIdsToOrders < ActiveRecord::Migration
  def change
    add_column :orders, :source_order_ids, :text, default: nil
  end
end
