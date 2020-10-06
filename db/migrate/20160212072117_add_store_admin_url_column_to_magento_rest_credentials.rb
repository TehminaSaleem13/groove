class AddStoreAdminUrlColumnToMagentoRestCredentials < ActiveRecord::Migration[5.1]
  def change
    add_column :magento_rest_credentials, :store_admin_url, :string
  end
end
