class AddAccessTokenColumnToMagentoRestCredential < ActiveRecord::Migration
  def change
    add_column :magento_rest_credentials, :access_token, :string
  end
end
