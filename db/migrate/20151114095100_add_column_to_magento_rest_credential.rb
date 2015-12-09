class AddColumnToMagentoRestCredential < ActiveRecord::Migration
  def change
    add_column :magento_rest_credentials, :oauth_token_secret, :string
  end
end
