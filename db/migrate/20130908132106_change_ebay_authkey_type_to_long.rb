class ChangeEbayAuthkeyTypeToLong < ActiveRecord::Migration
  def up
  	  remove_column :ebay_credentials, :auth_token
  	  remove_column :ebay_credentials, :productauth_token
  	  add_column :ebay_credentials, :auth_token, :text, :null=>false
  	  add_column :ebay_credentials, :productauth_token, :text, :null=>false
  end

  def down
  	  remove_column :ebay_credentials, :auth_token
  	  remove_column :ebay_credentials, :productauth_token
  	  add_column :ebay_credentials, :auth_token, :string, :default=>'', :null=>false
  	  add_column :ebay_credentials, :productauth_token, :string, :default=>'', :null=>false
  end
end
