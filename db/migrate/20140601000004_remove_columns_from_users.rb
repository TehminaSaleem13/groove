class RemoveColumnsFromUsers < ActiveRecord::Migration
  def up
    remove_column :users,   :access_scanpack
    remove_column :users,   :access_orders
    remove_column :users,   :access_products
    remove_column :users,   :access_settings
    remove_column :users,   :edit_product_details
    remove_column :users,   :add_products
    remove_column :users,   :edit_products
    remove_column :users,   :delete_products
    remove_column :users,   :import_products
    remove_column :users,   :edit_product_import
    remove_column :users,   :import_orders
    remove_column :users,   :change_order_status
    remove_column :users,   :createEdit_from_packer
    remove_column :users,   :createEdit_to_packer
    remove_column :users,   :add_order_items
    remove_column :users,   :remove_order_items
    remove_column :users,   :change_quantity_items
    remove_column :users,   :view_packing_ex
    remove_column :users,   :create_packing_ex
    remove_column :users,   :edit_packing_ex
    remove_column :users,   :create_users
    remove_column :users,   :remove_users
    remove_column :users,   :edit_user_info
    remove_column :users,   :edit_user_permissions
    remove_column :users,   :is_super_admin
    remove_column :users,   :edit_general_prefs
    remove_column :users,   :edit_scanning_prefs
    remove_column :users,   :edit_user_status
    remove_column :users,   :add_order_items_ALL

  end

  def down
    add_column :users,   :access_scanpack,        :boolean, :default => true,   :null => false
    add_column :users,   :access_orders,          :boolean, :default => false,  :null => false
    add_column :users,   :access_products,        :boolean, :default => false,  :null => false
    add_column :users,   :access_settings,        :boolean, :default => false,  :null => false
    add_column :users,   :edit_product_details,   :boolean, :default => false,  :null => false
    add_column :users,   :add_products,           :boolean, :default => false,  :null => false
    add_column :users,   :edit_products,          :boolean, :default => false,  :null => false
    add_column :users,   :delete_products,        :boolean, :default => false,  :null => false
    add_column :users,   :import_products,        :boolean, :default => false,  :null => false
    add_column :users,   :edit_product_import,    :boolean, :default => false,  :null => false
    add_column :users,   :import_orders,          :boolean, :default => false,  :null => false
    add_column :users,   :change_order_status,    :boolean, :default => false,  :null => false
    add_column :users,   :createEdit_from_packer, :boolean, :default => false,  :null => false
    add_column :users,   :createEdit_to_packer,   :boolean, :default => false,  :null => false
    add_column :users,   :add_order_items,        :boolean, :default => false,  :null => false
    add_column :users,   :remove_order_items,     :boolean, :default => false,  :null => false
    add_column :users,   :change_quantity_items,  :boolean, :default => false,  :null => false
    add_column :users,   :view_packing_ex,        :boolean, :default => false,  :null => false
    add_column :users,   :create_packing_ex,      :boolean, :default => false,  :null => false
    add_column :users,   :edit_packing_ex,        :boolean, :default => false,  :null => false
    add_column :users,   :create_users,           :boolean, :default => false,  :null => false
    add_column :users,   :remove_users,           :boolean, :default => false,  :null => false
    add_column :users,   :edit_user_info,         :boolean, :default => false,  :null => false
    add_column :users,   :edit_user_permissions,  :boolean, :default => false,  :null => false
    add_column :users,   :is_super_admin,         :boolean, :default => false,  :null => false
    add_column :users,   :edit_general_prefs,     :boolean, :default => false,  :null => false
    add_column :users,   :edit_scanning_prefs,    :boolean, :default => false,  :null => false
    add_column :users,   :edit_user_status,       :boolean, :default => false,  :null => false
    add_column :users,   :add_order_items_ALL,    :boolean, :default => false,  :null => false
  end
end
