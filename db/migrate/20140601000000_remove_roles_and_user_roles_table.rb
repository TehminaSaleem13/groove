class RemoveRolesAndUserRolesTable < ActiveRecord::Migration[5.1]
  def up
    drop_table :roles
    drop_table :users_roles
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
