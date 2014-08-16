class CreateUserInventoryPermissions < ActiveRecord::Migration
  def up
    create_table :user_inventory_permissions do |t|
      t.references :user, :null => false
      t.references :inventory_warehouse, :null => false
      t.boolean :see, :null => false, :default=> false
      t.boolean :edit, :null => false, :default=> false
    end

    add_index(:user_inventory_permissions, [:user_id, :inventory_warehouse_id], :unique => true, :name=>'index_user_inventory_permissions_user_inventory')
  end

  def down
    drop_table :user_inventory_permissions
  end
end
