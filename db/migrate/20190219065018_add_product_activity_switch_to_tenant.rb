class AddProductActivitySwitchToTenant < ActiveRecord::Migration
  def change
    add_column :tenants, :product_activity_switch, :boolean, :default => false
  end
end
