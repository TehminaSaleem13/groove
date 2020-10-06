class AddIsMultiBoxToTenant < ActiveRecord::Migration[5.1]
  def change
  	add_column :tenants, :is_multi_box, :boolean, :default => false
  end
end
