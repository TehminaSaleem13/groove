class AddSwitchToTenant < ActiveRecord::Migration[5.1]
  def change
  	add_column :tenants, :inventory_report_toggle, :boolean, :default => false
  end
end
