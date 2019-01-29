class AddTestTenantToggleToTenant < ActiveRecord::Migration
  def change
    add_column :tenants, :test_tenant_toggle, :boolean, :default => false
  end
end
