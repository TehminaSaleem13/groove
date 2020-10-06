class AddFieldToOrder < ActiveRecord::Migration[5.1]
  def change
  	add_column :orders, :already_scanned, :boolean, :default => false
  end
end
