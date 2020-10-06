class AddColumnToMagentoRestCredential < ActiveRecord::Migration[5.1]
  def change
    add_column :magento_rest_credentials, :oauth_token_secret, :string
  end
end
