class AddIndexesOnColumnsForOrders < ActiveRecord::Migration[5.1]
  def change
    add_index :orders, :increment_id
    add_index :orders, :store_id
  end
end
