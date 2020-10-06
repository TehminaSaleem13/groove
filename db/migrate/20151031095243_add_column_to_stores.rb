class AddColumnToStores < ActiveRecord::Migration[5.1]
  def change
    add_column :stores, :update_inv, :boolean, :default => false
  end
end
