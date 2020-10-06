class AddDuplicateTenantIdToTenants < ActiveRecord::Migration[5.1]
  def up
    add_column :tenants, :duplicate_tenant_id, :integer
  end

  def down
  	remove_column :tenants, :duplicate_tenant_id
  end
end
