class AddPasswordToSubscriptions < ActiveRecord::Migration[5.1]
  def up
    add_column :subscriptions, :password, :string, :null=> false
  end
  def down
    remove_column :subscriptions, :password
  end
end
