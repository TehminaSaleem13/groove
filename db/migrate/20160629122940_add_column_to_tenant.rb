class AddColumnToTenant < ActiveRecord::Migration
  def change
  	add_column :tenants, :orders_delete_days, :integer, :null => false, :default => 14
  end
end
