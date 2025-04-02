class AddAdministrativeUsersToAccessRestrictions < ActiveRecord::Migration[6.1]
  def change
    add_column :access_restrictions, :administrative_users, :integer, default: 0, null: false
  end
end
