class AddColumnsToEbayCredentials < ActiveRecord::Migration
  def change
    add_column :ebay_credentials, :ebay_auth_expiration, :date
    remove_column :ebay_credentials, :auth_token
    add_column :ebay_credentials, :auth_token, :string, :default=>''
    remove_column :ebay_credentials, :productauth_token
    add_column :ebay_credentials, :productauth_token, :string, :default=>''
  end
end
