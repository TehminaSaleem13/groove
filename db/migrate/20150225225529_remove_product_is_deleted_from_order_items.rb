class RemoveProductIsDeletedFromOrderItems < ActiveRecord::Migration[5.1]
  def up
    remove_column :order_items, :product_is_deleted
  end

  def down
    add_column :order_items, :product_is_deleted, :boolean
  end
end
