class AddFieldToTenant < ActiveRecord::Migration
  def change
  	add_column :tenants, :scheduled_import_toggle, :boolean, :default => false
  end
end
