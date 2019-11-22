class AddIsDelayInTenants < ActiveRecord::Migration
  def change
  	add_column :tenants, :is_delay, :boolean, :default => false
  end
end
