class AddStoreOrderIdToOrders < ActiveRecord::Migration
  def change
  	unless column_exists? :orders, :store_order_id
		  add_column :orders, :store_order_id, :string
		end
  end
end
