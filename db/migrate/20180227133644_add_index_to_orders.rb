class AddIndexToOrders < ActiveRecord::Migration
  def change
    remove_index :orders, :increment_id
    add_index :orders, :increment_id, :unique => true
  end
end
