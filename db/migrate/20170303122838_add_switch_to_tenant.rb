class AddSwitchToTenant < ActiveRecord::Migration
  def change
  	add_column :tenants, :inventory_report_toggle, :boolean, :default => false
  end
end
