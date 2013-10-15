class RemoveProductcolumnsFromMagentoAmazon < ActiveRecord::Migration
  def change
  remove_column :amazon_credentials, :productmerchant_id
  remove_column :amazon_credentials, :productmarketplace_id

  remove_column :magento_credentials, :producthost
  remove_column :magento_credentials, :productusername
  remove_column :magento_credentials, :productpassword
  remove_column :magento_credentials, :productapi_key
  end
end
