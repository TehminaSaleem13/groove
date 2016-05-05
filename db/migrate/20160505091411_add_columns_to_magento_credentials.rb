class AddColumnsToMagentoCredentials < ActiveRecord::Migration
  def change
    add_column :magento_credentials, :shall_import_processing, :boolean, :default => false
    add_column :magento_credentials, :shall_import_pending, :boolean, :default => false
    add_column :magento_credentials, :shall_import_closed, :boolean, :default => false
    add_column :magento_credentials, :shall_import_complete, :boolean, :default => false
    add_column :magento_credentials, :shall_import_fraud, :boolean, :default => false
    add_column :magento_credentials, :enable_status_update, :boolean, :default => false
    add_column :magento_credentials, :status_to_update, :string
  end
end
