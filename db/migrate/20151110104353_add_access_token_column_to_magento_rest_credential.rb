class AddAccessTokenColumnToMagentoRestCredential < ActiveRecord::Migration[5.1]
  def change
    add_column :magento_rest_credentials, :access_token, :string
  end
end
