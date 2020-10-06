class AddProductActivitySwitchToTenant < ActiveRecord::Migration[5.1]
  def change
    add_column :tenants, :product_activity_switch, :boolean, :default => false
  end
end
