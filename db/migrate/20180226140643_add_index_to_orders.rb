class AddIndexToOrders < ActiveRecord::Migration
  def up
    remove_index :orders, :increment_id if index_exists?(:orders, :increment_id)
    add_index :orders, :increment_id, :unique => true
  end

  def down
    remove_index :orders, :increment_id if index_exists?(:orders, :increment_id, unique: true)
    add_index :orders, :increment_id
  end
end
