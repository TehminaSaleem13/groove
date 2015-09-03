class AddDuplicateTenantIdToTenants < ActiveRecord::Migration
  def up
    add_column :tenants, :duplicate_tenant_id, :integer
  end

  def down
  	remove_column :tenants, :duplicate_tenant_id
  end
end
