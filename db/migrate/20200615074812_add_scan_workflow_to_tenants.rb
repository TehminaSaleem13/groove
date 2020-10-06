class AddScanWorkflowToTenants < ActiveRecord::Migration[5.1]
  def change
    add_column :tenants, :scan_pack_workflow, :string, :default => 'default'
  end
end
