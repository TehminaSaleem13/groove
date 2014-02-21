class AddPackingUserIdToOrders < ActiveRecord::Migration
  def change
    add_column :orders, :packing_user_id, :integer, references: :users
  end
end
