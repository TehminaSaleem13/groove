class AddUserColumnsToTheUsersTable < ActiveRecord::Migration
  def change
   	add_column :users, :access_scanpack, :boolean, :null => false, :default => 0
   	add_column :users, :access_orders, :boolean, :null => false, :default => 0
   	add_column :users, :access_products, :boolean, :null => false, :default => 0
   	add_column :users, :access_settings, :boolean, :null => false, :default => 0
    add_column :users, :active, :boolean, :null => false, :default => 0
   	add_column :users, :edit_product_details, :boolean, :null => false, :default => 0
   	add_column :users, :add_products, :boolean, :null => false, :default => 0
   	add_column :users, :edit_products, :boolean, :null => false, :default => 0
   	add_column :users, :delete_products, :boolean, :null => false, :default => 0
   	add_column :users, :import_products, :boolean, :null => false, :default => 0
    add_column :users, :edit_product_import, :boolean, :null => false, :default => 0
   	add_column :users, :import_orders, :boolean, :null => false, :default => 0
   	add_column :users, :change_order_status, :boolean, :null => false, :default => 0
   	add_column :users, :createEdit_from_packer, :boolean, :null => false, :default => 0
   	add_column :users, :createEdit_to_packer, :boolean, :null => false, :default => 0
   	add_column :users, :add_order_items, :boolean, :null => false, :default => 0
    add_column :users, :remove_order_items, :boolean, :null => false, :default => 0
   	add_column :users, :change_quantity_items, :boolean, :null => false, :default => 0
   	add_column :users, :view_packing_ex, :boolean, :null => false, :default => 0
   	add_column :users, :create_packing_ex, :boolean, :null => false, :default => 0
   	add_column :users, :edit_packing_ex, :boolean, :null => false, :default => 0
   	add_column :users, :create_users, :boolean, :null => false, :default => 0
    add_column :users, :remove_users, :boolean, :null => false, :default => 0
   	add_column :users, :edit_user_info, :boolean, :null => false, :default => 0
   	add_column :users, :edit_user_permissions, :boolean, :null => false, :default => 0
   	add_column :users, :is_super_admin, :boolean, :null => false, :default => 0
   	add_column :users, :edit_general_prefs, :boolean, :null => false, :default => 0
   	add_column :users, :edit_scanning_prefs, :boolean, :null => false, :default => 0
  end
end
