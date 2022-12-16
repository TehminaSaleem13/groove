class AddColumnToRole < ActiveRecord::Migration[5.1]
  def change
    add_column :roles, :edit_shipping_settings, :boolean, default: false, null: false
    add_column :roles, :edit_visible_services, :boolean, default: false, null: false
    add_column :roles, :add_edit_shortcuts, :boolean, default: false, null: false
    add_column :roles, :add_edit_dimension_presets, :boolean, default: false, null: false
  end
end
