class AddColumnToStore < ActiveRecord::Migration[5.1]
  def change
  	add_column :stores, :fba_import, :boolean, :default => false
  end
end
