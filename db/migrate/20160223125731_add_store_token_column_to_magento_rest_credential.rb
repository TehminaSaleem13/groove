class AddStoreTokenColumnToMagentoRestCredential < ActiveRecord::Migration
  def change
    add_column :magento_rest_credentials, :store_token, :string
  end
end
