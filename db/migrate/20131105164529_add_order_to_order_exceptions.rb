class AddOrderToOrderExceptions < ActiveRecord::Migration
  def change
    add_column :order_exceptions, :order_id, :integer
    add_index :order_exceptions, :order_id
  end
end
