class AddFieldToOrder < ActiveRecord::Migration
  def change
  	add_column :orders, :already_scanned, :boolean, :default => false
  end
end
