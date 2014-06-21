class AddRoleRefToUsers < ActiveRecord::Migration
  def change
    add_column :users, :role_id, :integer, references: :roles
    add_index :users, :role_id
  end
end
