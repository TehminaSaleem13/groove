class AddPasswordToSubscriptions < ActiveRecord::Migration
  def up
    add_column :subscriptions, :password, :string, :null=> false
  end
  def down
    remove_column :subscriptions, :password
  end
end
