class AddOriginStoreIdToOrders < ActiveRecord::Migration[5.1]
  def change
    add_column :orders, :origin_store_id, :integer
  end
end
