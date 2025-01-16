class AddAssignedUserToOrders < ActiveRecord::Migration[6.1]
  def change
    add_column :orders, :assigned_user_id, :integer
  end
end
