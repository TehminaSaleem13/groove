class AddProductToOrderItems < ActiveRecord::Migration
  def change
  	remove_column :orders, :product_id
    add_column :order_items, :product_id, :integer
  end
end
