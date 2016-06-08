class AddColumnToTenants < ActiveRecord::Migration
  def change
    add_column :tenants, :magento_tracking_push_enabled, :boolean, :default => false
  end
end
