class AddIsMultiBoxToTenant < ActiveRecord::Migration
  def change
  	add_column :tenants, :is_multi_box, :boolean, :default => false
  end
end
