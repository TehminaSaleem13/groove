class AddColumnIsDeletedToOrderItems < ActiveRecord::Migration
  def change
  	add_column :order_items, :is_deleted, :boolean, :default => false
  	add_index :order_items, :is_deleted
  end
end
