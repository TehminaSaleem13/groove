class AddIsFbaToTenant < ActiveRecord::Migration[5.1]
  def change
  	add_column :tenants, :is_fba, :boolean, :default => false
  end
end
