class DeleteColumnsFromAmazonCredentials < ActiveRecord::Migration
  def up
  remove_column :amazon_credentials, :productaccess_key_id
  remove_column :amazon_credentials, :productsecret_access_key
  remove_column :amazon_credentials, :productapp_name
  remove_column :amazon_credentials, :productapp_version
  
  remove_column :amazon_credentials, :access_key_id
  remove_column :amazon_credentials, :secret_access_key
  remove_column :amazon_credentials, :app_name
  remove_column :amazon_credentials, :app_version

  end

  def down
  add_column :amazon_credentials, :access_key_id, :string, :default=>'', :null=>false
  add_column :amazon_credentials, :secret_access_key, :string, :default=>'', :null=>false
  add_column :amazon_credentials, :app_name, :string, :default=>'', :null=>false
  add_column :amazon_credentials, :app_version, :string, :default=>'', :null=>false

  add_column :amazon_credentials, :productaccess_key_id, :string, :default=>'', :null=>false
  add_column :amazon_credentials, :productsecret_access_key, :string, :default=>'', :null=>false
  add_column :amazon_credentials, :productapp_name, :string, :default=>'', :null=>false
  add_column :amazon_credentials, :productapp_version, :string, :default=>'', :null=>false
  end
end
