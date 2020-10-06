class AddRoleRefToUsers < ActiveRecord::Migration[5.1]
  def change
    add_column :users, :role_id, :integer, references: :roles
    add_index :users, :role_id
  end
end
