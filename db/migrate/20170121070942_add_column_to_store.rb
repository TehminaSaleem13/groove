class AddColumnToStore < ActiveRecord::Migration
  def change
  	add_column :stores, :fba_import, :boolean, :default => false
  end
end
