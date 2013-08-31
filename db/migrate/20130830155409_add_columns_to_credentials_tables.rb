class AddColumnsToCredentialsTables < ActiveRecord::Migration
  def change
  add_column :magento_credentials, :producthost, :string, :default=>'', :null=>false
  add_column :magento_credentials, :productusername, :string, :default=>'', :null=>false
  add_column :magento_credentials, :productpassword, :string, :default=>'', :null=>false
  add_column :magento_credentials, :productapi_key, :string, :default=>'', :null=>false

  add_column :amazon_credentials, :productaccess_key_id, :string, :default=>'', :null=>false
  add_column :amazon_credentials, :productsecret_access_key, :string, :default=>'', :null=>false
  add_column :amazon_credentials, :productapp_name, :string, :default=>'', :null=>false
  add_column :amazon_credentials, :productapp_version, :string, :default=>'', :null=>false
  add_column :amazon_credentials, :productmerchant_id,:string, :default=>'', :null=>false
  add_column :amazon_credentials, :productmarketplace_id, :string, :default=>'', :null=>false

  add_column :ebay_credentials, :productdev_id, :string, :default=>'', :null=>false
  add_column :ebay_credentials, :productapp_id, :string, :default=>'', :null=>false
  add_column :ebay_credentials, :productcert_id, :string, :default=>'', :null=>false
  add_column :ebay_credentials, :productauth_token, :string, :default=>'', :null=>false

  add_column :ebay_credentials, :import_products, :boolean, :default=>0, :null=>false
  add_column :ebay_credentials, :import_images, :boolean, :default=>0, :null=>false
  
  add_column :amazon_credentials, :import_products, :boolean, :default=>0, :null=>false
  add_column :amazon_credentials, :import_images, :boolean, :default=>0, :null=>false

  add_column :magento_credentials, :import_products, :boolean, :default=>0, :null=>false
  add_column :magento_credentials, :import_images, :boolean, :default=>0, :null=>false
  end
end
