class AddColumnIsDeletedToOrderItems < ActiveRecord::Migration[5.1]
  def change
  	add_column :order_items, :is_deleted, :boolean, :default => false
  	add_index :order_items, :is_deleted
  end
end
