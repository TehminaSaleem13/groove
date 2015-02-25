class RemoveProductIsDeletedFromOrderItems < ActiveRecord::Migration
  def up
    remove_column :order_items, :product_is_deleted
  end

  def down
    add_column :order_items, :product_is_deleted, :boolean
  end
end
