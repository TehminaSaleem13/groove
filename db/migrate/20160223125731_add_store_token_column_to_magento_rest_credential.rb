class AddStoreTokenColumnToMagentoRestCredential < ActiveRecord::Migration[5.1]
  def change
    add_column :magento_rest_credentials, :store_token, :string
  end
end
