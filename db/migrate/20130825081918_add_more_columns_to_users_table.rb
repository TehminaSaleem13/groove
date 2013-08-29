class AddMoreColumnsToUsersTable < ActiveRecord::Migration
  def change
   	add_column :users, :edit_user_status, :boolean, :null => false, :default => 0
   	add_column :users, :add_order_items_ALL, :boolean, :null => false, :default => 0
	add_column :users, :other, :string
  end
end
