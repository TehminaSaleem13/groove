class AddFieldToTenant < ActiveRecord::Migration[5.1]
  def change
  	add_column :tenants, :scheduled_import_toggle, :boolean, :default => false
  end
end
