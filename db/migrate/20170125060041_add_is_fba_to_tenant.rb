class AddIsFbaToTenant < ActiveRecord::Migration
  def change
  	add_column :tenants, :is_fba, :boolean, :default => false
  end
end
