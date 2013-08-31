class AddApiKeyColumnToMagentoCredentialsTable < ActiveRecord::Migration
  def change
  	add_column :magento_credentials, :api_key, :string, :null=>false, :default=>""
  end
end
