class AddColumnToTenant < ActiveRecord::Migration[5.1]
  def change
  	add_column :tenants, :orders_delete_days, :integer, :null => false, :default => 14
  end
end
