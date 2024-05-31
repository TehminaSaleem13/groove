class AddIndexesToTables < ActiveRecord::Migration[5.1]
  def change
    add_index :products, :status
    add_index :order_items, :scanned_status
    add_index :order_items, :product_id
    add_index :stores, :name
  end
end
