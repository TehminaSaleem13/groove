class AddColumnsToRole < ActiveRecord::Migration[5.1]
  def change
    add_column :roles, :edit_product_location, :boolean, :default => false,  :null => false
    add_column :roles, :edit_product_quantity, :boolean, :default => false,  :null => false
  end
end
