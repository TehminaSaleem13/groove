class AddColumnToStores < ActiveRecord::Migration
  def change
    add_column :stores, :update_inv, :boolean, :default => false
  end
end
