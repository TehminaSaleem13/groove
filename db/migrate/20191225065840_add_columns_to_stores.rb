class AddColumnsToStores < ActiveRecord::Migration[5.1]
  def change
    add_column :stores, :quick_fix, :boolean, :default => false
    add_column :stores, :troubleshooter_option, :boolean, :default => false
  end
end
