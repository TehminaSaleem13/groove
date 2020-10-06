class AddApiKeyColumnToMagentoCredentialsTable < ActiveRecord::Migration[5.1]
  def change
  	add_column :magento_credentials, :api_key, :string, :null=>false, :default=>""
  end
end
