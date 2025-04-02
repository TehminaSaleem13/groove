class AddRegularUsersToAccessRestrictions < ActiveRecord::Migration[6.1]
  def change
    add_column :access_restrictions, :regular_users, :integer, default: 0, null: false
  end
end
