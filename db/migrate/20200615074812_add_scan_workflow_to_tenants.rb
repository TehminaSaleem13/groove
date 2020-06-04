class AddScanWorkflowToTenants < ActiveRecord::Migration
  def change
    add_column :tenants, :scan_pack_workflow, :string, :default => 'default'
  end
end
