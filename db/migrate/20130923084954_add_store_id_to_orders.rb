class AddStoreIdToOrders < ActiveRecord::Migration
  def change
    add_column :orders, :store_order_id, :string
  end
end
