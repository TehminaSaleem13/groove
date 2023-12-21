class ChangeNullToMagentoCredentials < ActiveRecord::Migration[5.1]
  def up
    change_column :magento_credentials, :api_key, :string, default: '', null: true
    change_column :magento_credentials, :host, :string, null: true
    change_column :magento_credentials, :username, :string, null: true
  end

  def down
    change_column :magento_credentials, :api_key, :string, default: '', null: false
    change_column :magento_credentials, :host, :string, null: false
    change_column :magento_credentials, :username, :string, null: false
  end
end
