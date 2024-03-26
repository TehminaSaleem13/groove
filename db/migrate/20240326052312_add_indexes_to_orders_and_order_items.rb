class AddIndexesToOrdersAndOrderItems < ActiveRecord::Migration[5.1]
  def change
    add_index :orders, :id
    add_index :order_items, :qty
  end
end
