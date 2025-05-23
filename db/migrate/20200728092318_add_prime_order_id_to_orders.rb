class AddPrimeOrderIdToOrders < ActiveRecord::Migration[5.1]
  def up
    add_column :orders, :prime_order_id, :string unless column_exists? :orders, :prime_order_id
  end

  def down
    remove_column :orders, :prime_order_id if column_exists? :orders, :prime_order_id
  end
end
