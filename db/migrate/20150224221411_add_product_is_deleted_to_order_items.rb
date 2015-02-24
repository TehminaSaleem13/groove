class AddProductIsDeletedToOrderItems < ActiveRecord::Migration
  def change
    add_column :order_items, :product_is_deleted, :boolean, default: false
  end
end
