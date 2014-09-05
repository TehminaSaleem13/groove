class AddUsernameToSubscriptions < ActiveRecord::Migration
  def up
    add_column :subscriptions, :user_name, :string, :null=> false
  end
  def down
    remove_column :subscriptions, :user_name
  end
end
