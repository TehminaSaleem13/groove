class AddTestTenantToggleToTenant < ActiveRecord::Migration[5.1]
  def change
    add_column :tenants, :test_tenant_toggle, :boolean, :default => false
  end
end
