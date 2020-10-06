class AddPackingUserIdToOrders < ActiveRecord::Migration[5.1]
  def change
    add_column :orders, :packing_user_id, :integer, references: :users
  end
end
