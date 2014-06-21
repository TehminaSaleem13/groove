class CreateRoles < ActiveRecord::Migration
  def up
    create_table :roles do |t|
      t.string   :name,                   :unique  => true,   :null => false
      t.boolean  :display,                :default => false,  :null => false
      t.boolean  :custom,                 :default => true,   :null => false

      t.boolean  :add_edit_order_items,   :default => false,  :null => false
      t.boolean  :import_orders,          :default => false,  :null => false
      t.boolean  :change_order_status,    :default => false,  :null => false
      t.boolean  :create_edit_notes,      :default => false,  :null => false
      t.boolean  :view_packing_ex,        :default => false,  :null => false
      t.boolean  :create_packing_ex,      :default => false,  :null => false
      t.boolean  :edit_packing_ex,        :default => false,  :null => false

      t.boolean  :delete_products,        :default => false,  :null => false
      t.boolean  :import_products,        :default => false,  :null => false
      t.boolean  :add_edit_products,      :default => false,  :null => false

      t.boolean  :add_edit_users,         :default => false,  :null => false
      t.boolean  :make_super_admin,       :default => false,  :null => false

      t.boolean  :access_scanpack,        :default => true,   :null => false
      t.boolean  :access_orders,          :default => false,  :null => false
      t.boolean  :access_products,        :default => false,  :null => false
      t.boolean  :access_settings,        :default => false,  :null => false


      t.boolean  :edit_general_prefs,     :default => false,  :null => false
      t.boolean  :edit_scanning_prefs,    :default => false,  :null => false
      t.boolean  :add_edit_stores,        :default => false,  :null => false
      t.boolean  :create_backups,         :default => false,  :null => false
      t.boolean  :restore_backups,        :default => false,  :null => false
    end

  end

  def down
    drop_table :roles
  end
end
