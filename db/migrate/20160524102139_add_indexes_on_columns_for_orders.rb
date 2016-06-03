class AddIndexesOnColumnsForOrders < ActiveRecord::Migration
  def change
    add_index :orders, :increment_id
    add_index :orders, :store_id
  end
end
