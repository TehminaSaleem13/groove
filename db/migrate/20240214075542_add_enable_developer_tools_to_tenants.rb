class AddEnableDeveloperToolsToTenants < ActiveRecord::Migration[5.1]
  def change
    add_column :tenants, :enable_developer_tools, :boolean, default: false
  end
end
