class AddColumnToTenants < ActiveRecord::Migration[5.1]
  def change
    add_column :tenants, :magento_tracking_push_enabled, :boolean, :default => false
  end
end
