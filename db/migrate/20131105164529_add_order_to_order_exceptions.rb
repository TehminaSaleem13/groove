class AddOrderToOrderExceptions < ActiveRecord::Migration[5.1]
  def change
    add_column :order_exceptions, :order_id, :integer
    add_index :order_exceptions, :order_id
  end
end
